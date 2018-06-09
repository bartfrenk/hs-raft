module Raft.Leader where

import Control.Distributed.Process

import Raft.State
import Raft.Types

run :: Env -> Process Role
run _ = pure $ Follower
