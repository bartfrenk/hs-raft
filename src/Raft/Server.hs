{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE TemplateHaskell #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}

module Raft.Server where

import Control.Distributed.Process.Lifted
import Control.Distributed.Process.Lifted.Class
import Control.Lens
import Control.Monad.Cont
import Control.Monad.Reader
import Control.Monad.State
import Data.Binary
import Data.Typeable

import qualified Distributed.Timer as Timer

import Raft.Messages
import Raft.Types
import Utils

newtype Pids =
  Pids [ProcessId]
  deriving (Typeable, Binary, Show)

data ElectionState = ElectionState
  { timer :: Timer.Ref
  , pendingVotes :: [ReceivePort VoteResponse]
  , received :: Int
  , granted :: Int
  }

server :: MonadServer m => m ()
server = say "starting server" >> loop
  where
    loop = do
      use role >>= \case
        Candidate -> candidate
        Follower -> follower
        Leader -> leader
      loop

initElectionState :: MonadServer m => m ElectionState
initElectionState = do
  timer <- startElectionTimer
  pendingVotes <- use peers >>= mapM sendVoteRequest
  pure $
    ElectionState {timer = timer, pendingVotes = pendingVotes, received = 1, granted = 1}
  where
    sendVoteRequest serverAddress = do
      (sendPort, receivePort) <- newChan
      newVoteRequest sendPort >>= send serverAddress
      pure receivePort
    newVoteRequest sendPort =
      VoteRequest <$> use currentTerm <*> getSelfId <*> pure sendPort

getSelfId :: MonadServer m => m ServerId
getSelfId = getSelfPid

killElectionState :: MonadServer m => ElectionState -> m ()
killElectionState estate = Timer.cancel $ timer estate

candidate :: MonadServer m => m ()
candidate = do
  bracket initElectionState killElectionState loop
  where
    loop estate = whenM (hasRole Candidate) $ handle estate loop
    handle :: MonadServer m => ElectionState -> (ElectionState -> m ()) -> m ()
    handle estate@ElectionState {..} cont =
      controlP $ \run ->
        receiveWait $
        [match $ run . (handleElectionTimeout estate cont)] ++
        ((\p -> matchChan p $ run . handleVoteResponse estate cont) <$>
         pendingVotes)

handleElectionTimeout ::
     MonadServer m
  => ElectionState
  -> (ElectionState -> m ())
  -> ElectionTimeout
  -> m ()
handleElectionTimeout estate _cont _ = Timer.cancel (timer estate) >> pure ()

handleVoteResponse ::
     MonadServer m
  => ElectionState
  -> (ElectionState -> m ())
  -> VoteResponse
  -> m ()
handleVoteResponse ElectionState{..} cont VoteResponse{..} =
  ((< term) <$> use currentTerm) >>= \case
    True ->
      let newElectionState = ElectionState
             { timer = timer
             , pendingVotes = pendingVotes
             , granted = granted + if voteGranted then 1 else 0
             , received = received + 1
             }
      in electionResult newElectionState >>= \case
        Won -> role .= Leader
        Lost -> role .= Follower
        Undecided -> cont newElectionState

    False -> role .= Follower

electionResult :: MonadServer m => ElectionState -> m ElectionResult
electionResult ElectionState{received, granted} = do
  n <- length <$> use peers
  if granted > n `div` 2 then pure Won
    else if granted + (n - received) <= n `div` 2 then pure Lost
    else pure Undecided

data ElectionResult
  = Won
  | Lost
  | Undecided

startElectionTimer :: MonadServer m => m Timer.Ref
startElectionTimer = do
  ms <- reader electionTimeout >>= sample
  pid <- getSelfPid
  say $ "starting timer: " ++ show ms
  Timer.start [ms] pid ElectionTimeout

handleHeartbeatTimeout :: MonadServer m => ElectionTimeout -> m ()
handleHeartbeatTimeout _ = role .= Candidate

handleAppendEntries :: MonadServer m => Timer.Ref -> AppendEntries -> m ()
handleAppendEntries timer _ = Timer.reset timer

hasRole :: MonadState ServerState m => Role -> m Bool
hasRole r = ((==) r) `fmap` use role

whenM :: Monad m => m Bool -> m () -> m ()
whenM prop' act = do
  prop <- prop'
  when prop act

follower :: MonadServer m => m ()
follower = bracket startElectionTimer Timer.cancel loop
  where
    loop timer = whenM (hasRole Follower) (handle timer >> loop timer)
    handle :: MonadServer m => Timer.Ref -> m ()
    handle timer =
      controlP $ \run ->
        receiveWait
          [ match $ run . handleHeartbeatTimeout
          , match $ run . handleAppendEntries timer
          ]

leader :: MonadServer m => m ()
leader = use role >>= say . show >> delay (milliseconds 1000)

initialState :: ServerState
initialState =
  ServerState
  { _currentTerm = initialTerm
  , _votedFor = Nothing
  , _role = Follower
  , _peers = []
  }

initialTerm :: Term
initialTerm = Term 0

-- | Start a Raft server with the specified environment and peers.
start :: ServerEnv -> [ProcessId] -> Process ()
start env peers = evalServer (setPeers >> server) initialState env
  where
    setPeers = modify $ \state -> state {_peers = peers}
--remotable ['start]
