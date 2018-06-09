module Raft.State
  ( Env
  , Config(..)
  , defaultConfig
  , incTerm
  , setRole
  , atomically
  , voteFor
  , hasVoted
  , drawElectionTimeout
  , drawLeaderHeartbeatTimeout
  , setTerm
  , getTerm
  , getPeers
  , getSelfID
  , newEnv
  ) where

import Control.Distributed.Process
import Control.Monad.Trans (MonadIO, liftIO)
import Control.Concurrent.STM as STM
import System.Random
import Data.Maybe

import Utils.Duration
import Raft.Types (PeerID, PeerAddress, Role(..))

data State = State
  { role :: TVar Role
  , term :: TVar Int
  , votedFor :: TVar (Maybe PeerID)
  , peers :: TVar [PeerAddress]
  }

defaultConfig :: Config
defaultConfig = Config
  { electionTimeout = (milliseconds 150, milliseconds 300) }

data Config = Config
  { electionTimeout :: (Duration, Duration)
  }

data Env = Env
  { state :: State
  , config :: Config
  , gen :: TVar StdGen
  }

newEnv :: MonadIO m => StdGen -> Config -> [PeerAddress] -> m Env
newEnv gen config peers = do
  state <- newState peers
  g <- liftIO $ newTVarIO gen
  pure $ Env
    { state = state
    , config = config
    , gen = g
    }

newState :: MonadIO m => [PeerAddress] -> m State
newState peers = liftIO $ State <$>
  newTVarIO Follower <*>
  newTVarIO 0 <*>
  newTVarIO Nothing <*>
  newTVarIO peers

hasVoted :: MonadIO m => Env -> m Bool
hasVoted env = liftIO . atomically $
  isJust <$> readTVar (votedFor $ state env)

voteFor :: MonadIO m => Env -> PeerID -> m ()
voteFor env peer = liftIO . atomically $
  writeTVar (votedFor $ state env) (Just peer)

clearVote :: Env -> STM ()
clearVote env = writeTVar (votedFor $ state env) Nothing

setTerm :: MonadIO m => Env -> Int -> m ()
setTerm env t' = modifyTerm env (\_ -> t')

modifyTerm :: MonadIO m => Env -> (Int -> Int) -> m ()
modifyTerm env f =
  let v = term $ state env
  in liftIO . atomically $ do
    t <- readTVar v
    let t' = f t
    if t /= t'
      then writeTVar v t' >> clearVote env
      else pure ()

getTerm :: MonadIO m => Env -> m Int
getTerm env = liftIO $ readTVarIO (term $ state env)

-- | Dependence on @Env@, since we might need to fabricate a custom ID type from
-- the environment in the future. For now, just use the process ID.
getSelfID :: Env -> Process PeerID
getSelfID _ = getSelfPid

getSelfAddress :: Env -> Process PeerAddress
getSelfAddress _ = getSelfPid

incTerm :: MonadIO m => Env -> m ()
incTerm env = modifyTerm env (+ 1)

setRole :: MonadIO m => Env -> Role -> m ()
setRole env =  liftIO . atomically . writeTVar (role $ state env)

getPeers :: Env -> Process [PeerAddress]
getPeers env = do
  peers <- liftIO $ atomically $ readTVar (peers $ state env)
  selfAddress <- getSelfAddress env
  pure $ filter (/= selfAddress) peers

drawElectionTimeout :: MonadIO m => Env -> m Duration
drawElectionTimeout env =
  let v = gen env
  in liftIO $ atomically $ do
    g <- readTVar v
    let (a, g') = randomR (electionTimeout $ config env) g
    writeTVar v g'
    pure a

-- | The maximal time between successive heartbeat messages from the leader.
-- The Raft article seems to indicate that this equals the election timeout, see
-- p.6.
drawLeaderHeartbeatTimeout :: MonadIO m => Env -> m Duration
drawLeaderHeartbeatTimeout = drawElectionTimeout
