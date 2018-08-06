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
startLeaderHeartbeatTimer :: Env -> Process T.Ref
startLeaderHeartbeatTimer env = do
  d <- drawLeaderHeartbeatTimeout env
  pid <- getSelfPid
  T.startTimer d pid T.Tick

-- | Runs the server in the `follower` role.
run :: Env -> Process Role
run env = bracket (startLeaderHeartbeatTimer env) T.cancelTimer $ loop
  where
    loop timer = do
      status <- receiveWait
                [ match $ processAppendEntries env timer
                , match $ processBallot env ()
                , match $ processTimeout
                , match $ processControl env ()
                , match $ processInspectRequest env ()
                ]
      case status of
        InProgress () -> loop timer
        Superseded -> loop timer
        -- Waited too long for a heartbeat message from the leader.
        Timeout -> pure Candidate
        Controlled Disable -> pure Disabled
        Controlled _ -> loop timer

processAppendEntries :: Env -> T.Ref -> AppendEntries -> Process (Status ())
processAppendEntries env timer msg =
  let t' = term (msg :: AppendEntries)
      cont = T.resetTimer timer >> (pure $ InProgress ())
      superseded = T.resetTimer timer
  in do
    status <- checkTerm env t' cont superseded
    send (sender msg) =<< newAppendEntriesResp env msg
    pure status


processTimeout :: T.Tick -> Process (Status ())
processTimeout _ = pure $ Timeout
