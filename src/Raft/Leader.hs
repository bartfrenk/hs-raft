{-# LANGUAGE ScopedTypeVariables #-}

module Raft.Leader where

import           Control.Distributed.Process hiding (bracket)
import           Control.Monad.Catch

import qualified Utils.Timer                 as T

import           Raft.Messages
import           Raft.Shared
import           Raft.State
import           Raft.Types

startHeartbeatTicker :: Env cmd -> Process T.Ref
startHeartbeatTicker env = do
  dt <- getHeartbeatInterval env
  say $ "Heartbeat interval: " ++ show dt
  pid <- getSelfPid
  T.startTicker dt pid T.Tick

run :: RaftCommand cmd => Env cmd -> Process Role
run env = bracket (startHeartbeatTicker env) T.cancelTimer $ loop
  where
    loop timer = do
      status <-
        receiveWait
          [ match $ processBallot env ()
          , match $ processTicker env
          , match $ processAppendEntries env
          , match $ processAppendEntriesResp env ()
          , match $ processControl env ()
          , match $ processInspectRequest env ()
          , match $ processSubmitCommand env
          ]
      case status of
        InProgress () -> loop timer
        Superseded -> pure Follower
        Timeout -> loop timer -- should not happen
        Controlled (SetRole role) -> pure role
        Controlled _ -> loop timer

processSubmitCommand ::
     RaftCommand cmd => Env cmd -> SubmitCommand cmd -> Process (Status ())
processSubmitCommand env msg = do
  say $ "Received command: " ++ show (cmd msg)
  appendToLog env (cmd msg)
  pure $ InProgress ()

processTicker :: RaftCommand cmd => Env cmd -> T.Tick -> Process (Status ())
processTicker env _ = do
  mapM_ (sendAppendEntries env) =<< (getPeers env)
  pure $ InProgress ()
  where
    sendAppendEntries env pid = send pid =<< newAppendEntries env pid

newAppendEntries :: Env cmd -> ProcessId -> Process (AppendEntries cmd)
newAppendEntries env pid = do
  t <- getTerm env
  sender <- getSelfPid
  (prevLogTerm, prevLogIndex, entries) <- getEntriesToSend env pid
  leaderCommit <- getCommitIndex env
  pure $
    AppendEntries
    { aeTerm = t
    , aeSender = sender
    , prevLogIndex = prevLogIndex
    , prevLogTerm = prevLogTerm
    , entries = entries
    , leaderCommit = leaderCommit
    }

processAppendEntries :: Env cmd -> AppendEntries cmd -> Process (Status ())
processAppendEntries env msg = do
  t <- getTerm env
  let t' = aeTerm msg
  if t' <= t -- Note that the candidate is superseded when t = t'
    then pure $ InProgress ()
    else setTerm env t' >> pure Superseded
