module Raft.State
  ( Env
  , Role(..)
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
import Data.Maybe

import Utils
import Raft.Types (PeerID, PeerAddress)

data Role = Candidate | Follower | Leader


data State = State
  { role :: TVar Role
  , term :: TVar Int
  , votedFor :: TVar (Maybe PeerID)
  , peers :: TVar [PeerAddress]
  }

data Config = Config
  {
  }

data Env = Env
  { state :: State
  , config :: Config
  }

newEnv :: MonadIO m => m Env
newEnv = undefined

newState :: MonadIO m => m State
newState = undefined

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

incTerm :: MonadIO m => Env -> m ()
incTerm env = modifyTerm env (+ 1)

setRole :: MonadIO m => Env -> Role -> m ()
setRole env =  liftIO . atomically . writeTVar (role $ state env)

getPeers :: MonadIO m => Env -> m [PeerAddress]
getPeers env = liftIO $ atomically $ readTVar (peers $ state env)

drawElectionTimeout :: MonadIO m => Env -> m Duration
drawElectionTimeout = undefined

-- | The maximal time between successive heartbeat messages from the leader.
-- The Raft article seems to indicate that this equals the election timeout, see
-- p.6.
drawLeaderHeartbeatTimeout :: MonadIO m => Env -> m Duration
drawLeaderHeartbeatTimeout = drawElectionTimeout
