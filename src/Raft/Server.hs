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

showRole :: Role -> String
showRole Candidate = "candidate"
showRole Follower = "follower"
showRole Leader = "leader"

-- | Runs a Raft server in environment `env` with role `role`.
run :: Env -> Role -> Process ()
run env role = do
  say $ "Running server as " ++ showRole role
  role' <- case role of
    Follower -> Follower.run env
    Candidate -> Candidate.run env
    Leader -> Leader.run env
  run env role'

-- | Start a Raft server with the specified environment and peers.
start :: StdGen -> Config -> [PeerAddress] -> Process ()
start gen config peers = do
  env <- newEnv gen config peers
  run env Follower

