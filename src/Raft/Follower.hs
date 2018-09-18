module Raft.Follower where

import Control.Monad.Catch
import Control.Distributed.Process hiding (bracket)

import qualified Utils.Timer as T

import Raft.Messages
import Raft.State
import Raft.Types
import Raft.Shared

-- | Starts the timer that sends a tick when too much time passes between
-- subsequent heartbeat messages.
startLeaderHeartbeatTimer :: Env cmd -> Process T.Ref
startLeaderHeartbeatTimer env = do
  d <- drawLeaderHeartbeatTimeout env
  pid <- getSelfPid
  T.startTimer d pid T.Tick

-- | Runs the server in the `follower` role.
run :: RaftCommand cmd => Env cmd -> Process Role
run env = bracket (startLeaderHeartbeatTimer env) T.cancelTimer $ loop
  where
    loop timer = do
      status <- receiveWait
                [ match $ processBallot env ()
                , match $ processAppendEntries env timer
                , match $ processTimeout
                , match $ processControl env ()
                , match $ processInspectRequest env ()
                ]
      case status of
        InProgress () -> loop timer
        Superseded -> loop timer
        -- Waited too long for a heartbeat message from the leader.
        Timeout -> pure Candidate
        Controlled (SetRole role) -> pure role
        Controlled _ -> loop timer


processAppendEntries :: Env cmd -> T.Ref -> AppendEntries cmd -> Process (Status ())
processAppendEntries env timer msg =
  let t' = term msg
      s = aeSender msg
      cont = T.resetTimer timer >> (pure $ InProgress ())
      superseded = T.resetTimer timer
  in do
    status <- checkTerm env t' cont superseded
    send s =<< newAppendEntriesResp env msg
    pure status


processTimeout :: T.Tick -> Process (Status ())
processTimeout _ = do
  say "Time out waiting for heartbeat"
  pure $ Timeout
