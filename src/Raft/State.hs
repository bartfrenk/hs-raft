module Raft.State
  ( Env
  , Config(..)
  , defaultConfig
  , appendToLog
  , incTerm
  , setRole
  , atomically
  , getCommitIndex
  , getEntriesToSend
  , voteFor
  , hasVoted
  , hasVotedFor
  , drawElectionTimeout
  , drawLeaderHeartbeatTimeout
  , setTerm
  , getTerm
  , getPeers
  , getRole
  , getLogTerms
  , getSelfID
  , getSelfAddress
  , newEnv
  , getHeartbeatInterval
  ) where

-- TODO: Move to IORef

import           Prelude                     hiding (log)

import           Control.Concurrent.STM      as STM
import           Control.Distributed.Process
import           Control.Monad               (when)
import           Control.Monad.Trans         (MonadIO, liftIO)
import           Data.Map.Strict             (Map, (!))
import qualified Data.Map.Strict             as Map
import           Data.Maybe
import           Data.Proxy
import           Data.Sequence               (Seq, (|>))
import qualified Data.Sequence               as Seq
import           System.Random

import           Raft.Types                  (PeerAddress, PeerID, RaftCommand,
                                              Role (..))
import           Utils.Duration

-- TODO: at least a type alias for the type of terms
-- TODO: consider uints
data State cmd = State
  { role        :: TVar Role -- ^ The current role of the node.
  , term        :: TVar Int -- ^ The latest term the node has seen.
  , votedFor    :: TVar (Maybe PeerID) -- ^ The candidate voted for in this term.
  , peers       :: TVar [PeerAddress] -- ^ Adressess of all raft nodes in the cluster.
  , log         :: TVar (Seq (Int, cmd)) -- ^ The log of commands
  , commitIndex :: TVar Int -- ^ Index of highest log entry known to be committed
  , lastApplied :: TVar Int -- ^ Index of highest log entry known to be applied
  }

getCommitIndex :: MonadIO m => Env cmd -> m Int
getCommitIndex Env{state} =
  liftIO $ readTVarIO $ commitIndex state

getEntriesToSend :: MonadIO m => Env cmd -> ProcessId -> m (Maybe Int, Int, Seq (Int, cmd))
getEntriesToSend Env{leaderState, state} pid = liftIO $ do
  nxt <- (! pid) <$> readTVarIO (nextIndex leaderState)
  lg <- readTVarIO (log state)
  pure $ entriesToSend nxt lg

entriesToSend :: Int -> Seq (Int, cmd) -> (Maybe Int, Int, Seq (Int, cmd))
entriesToSend nxt lg
  | nxt > 0 = let relevant = Seq.drop (nxt - 1) lg
              in (fst <$> Seq.lookup 0 relevant, nxt - 1, Seq.drop 1 relevant)
  | nxt == 0 = (Nothing, -1, lg)
  | otherwise = error "Should not happen"

data LeaderState = LeaderState
  { nextIndex  :: TVar (Map ProcessId Int)
  , matchIndex :: TVar (Map ProcessId Int)
  }

initLeaderState :: Env cmd -> STM ()
initLeaderState Env {state, leaderState} = do
  next <- length <$> readTVar (log state)
  p <- readTVar (peers state)
  writeTVar (nextIndex leaderState) $ Map.fromList $ zip p (repeat next)
  writeTVar (matchIndex leaderState) $ Map.fromList $ zip p (repeat (-1))

appendToLog :: MonadIO m => Env cmd -> cmd -> m ()
appendToLog Env {state} cmd =
  let logRef = log state
  in liftIO $
     atomically $ do
       t <- readTVar (term state)
       modifyTVar logRef (|> (t, cmd))

getLogTerms :: MonadIO m => Env cmd -> m (Seq Int)
getLogTerms Env{state} =
  liftIO $ (fmap fst) <$> readTVarIO (log state)

defaultConfig :: Config
defaultConfig =
  Config
  {
    -- Maximum time an election may last. Also, the maximum time a follower
    -- can go without hearing from the leader.
    electionTimeout = (milliseconds 150, milliseconds 300)
    -- Time between subsequent leader heartbeats.
  , heartbeatInterval = microseconds 500
  }

data Config = Config
  { electionTimeout   :: (Duration, Duration)
  , heartbeatInterval :: Duration
  }

data Env cmd = Env
  { state       :: State cmd
  , config      :: Config
  , gen         :: TVar StdGen
  , leaderState :: LeaderState
  }

newEnv ::
     (RaftCommand cmd, MonadIO m)
  => Proxy cmd
  -> StdGen
  -> Config
  -> [PeerAddress]
  -> m (Env cmd)
newEnv _ gen config peers = do
  state <- newState peers
  g <- liftIO $ newTVarIO gen
  leaderState <- emptyLeaderState
  pure $ Env {state = state, config = config, gen = g, leaderState = leaderState}

emptyLeaderState :: MonadIO m => m LeaderState
emptyLeaderState = liftIO $ do
  nextIndex <- newTVarIO Map.empty
  matchIndex <- newTVarIO Map.empty
  pure $ LeaderState
    { nextIndex = nextIndex
    , matchIndex = matchIndex
    }

getHeartbeatInterval :: MonadIO m => (Env cmd) -> m Duration
getHeartbeatInterval = pure . heartbeatInterval . config

newState :: MonadIO m => [PeerAddress] -> m (State cmd)
newState peers = do
  roleRef <- liftIO $ newTVarIO Follower
  termRef <- liftIO $ newTVarIO 0
  votedForRef <- liftIO $ newTVarIO Nothing
  peersRef <- liftIO $ newTVarIO peers
  logRef <- liftIO $ newTVarIO (Seq.empty)
  commitIndexRef <- liftIO $ newTVarIO (-1)
  lastAppliedRef <- liftIO $ newTVarIO (-1)
  pure $
    State
    { role = roleRef
    , term = termRef
    , votedFor = votedForRef
    , peers = peersRef
    , log = logRef
    , commitIndex = commitIndexRef
    , lastApplied = lastAppliedRef
    }

hasVoted :: MonadIO m => (Env cmd) -> m Bool
hasVoted env = liftIO . atomically $ isJust <$> readTVar (votedFor $ state env)

hasVotedFor :: MonadIO m => (Env cmd) -> m (Maybe ProcessId)
hasVotedFor env = liftIO . atomically $ readTVar (votedFor $ state env)

voteFor :: MonadIO m => (Env cmd) -> PeerID -> m ()
voteFor env peer =
  liftIO . atomically $ writeTVar (votedFor $ state env) (Just peer)

clearVote :: (Env cmd) -> STM ()
clearVote env = writeTVar (votedFor $ state env) Nothing

setTerm :: MonadIO m => (Env cmd) -> Int -> m ()
setTerm env t' = modifyTerm env (\_ -> t')

modifyTerm :: MonadIO m => (Env cmd) -> (Int -> Int) -> m ()
modifyTerm env f =
  let v = term $ state env
  in liftIO . atomically $ do
       t <- readTVar v
       let t' = f t
       if t /= t'
         then writeTVar v t' >> clearVote env
         else pure ()

getTerm :: MonadIO m => (Env cmd) -> m Int
getTerm env = liftIO $ readTVarIO (term $ state env)

getRole :: MonadIO m => (Env cmd) -> m Role
getRole env = liftIO $ readTVarIO (role $ state env)

-- | Dependence on @Env@, since we might need to fabricate a custom ID type from
-- the environment in the future. For now, just use the process ID.
getSelfID :: (Env cmd) -> Process PeerID
getSelfID _ = getSelfPid

getSelfAddress :: (Env cmd) -> Process PeerAddress
getSelfAddress _ = getSelfPid

incTerm :: MonadIO m => (Env cmd) -> m ()
incTerm env = modifyTerm env (+ 1)

setRole :: MonadIO m => (Env cmd) -> Role -> m ()
setRole env r =
  liftIO . atomically $ do
    writeTVar (role $ state env) r
    when (r == Leader) $ initLeaderState env

getPeers :: (Env cmd) -> Process [PeerAddress]
getPeers env = do
  peers <- liftIO $ atomically $ readTVar (peers $ state env)
  selfAddress <- getSelfAddress env
  pure $ filter (/= selfAddress) peers

drawElectionTimeout :: MonadIO m => (Env cmd) -> m Duration
drawElectionTimeout env =
  let v = gen env
  in liftIO $
     atomically $ do
       g <- readTVar v
       let (a, g') = randomR (electionTimeout $ config env) g
       writeTVar v g'
       pure a

-- | The maximal time between successive heartbeat messages from the leader.
-- The Raft article seems to indicate that this equals the election timeout, see
-- p.6.
drawLeaderHeartbeatTimeout :: MonadIO m => (Env cmd) -> m Duration
drawLeaderHeartbeatTimeout = drawElectionTimeout
