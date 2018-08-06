module Raft.Disabled where

import Control.Distributed.Process hiding (bracket)

import Raft.Messages
import Raft.State
import Raft.Types
import Raft.Shared

run :: Env -> Process Role
run env = do
  status <- receiveWait
    [ match $ processControl env ()
    , match $ processInspectRequest env ()
    , matchAny $ \_ -> pure $ InProgress ()] -- discard non-control messages
  case status of
    Controlled Enable -> getRole env
    _ -> run env
