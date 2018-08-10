{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE TemplateHaskell #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}

module Raft.Server where

import System.Random
import Control.Distributed.Process

import Raft.State
import Raft.Types

import qualified Raft.Candidate as Candidate
import qualified Raft.Follower as Follower
import qualified Raft.Leader as Leader
import qualified Raft.Disabled as Disabled

showRole :: Role -> String
showRole Candidate = "candidate"
showRole Follower = "follower"
showRole Leader = "leader"
showRole Disabled = "disabled"

-- | Runs a Raft server in environment `env` with role `role`.
run :: Env -> Role -> Process ()
run env role = do
  t <- getTerm env
  say $ "Running in " ++ show t ++ " as " ++ showRole role
  role' <- case role of
    Follower -> setRole env role >> Follower.run env
    Candidate -> setRole env role >> Candidate.run env
    Leader -> setRole env role >> Leader.run env
    Disabled -> Disabled.run env -- remember the previous role
  run env role'

-- | Start a Raft server with the specified environment and peers.
start :: StdGen -> Config -> [PeerAddress] -> Process ()
start gen config peers = do
  env <- newEnv gen config peers
  run env Follower

