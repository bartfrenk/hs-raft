{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase                 #-}
{-# LANGUAGE NamedFieldPuns             #-}
{-# LANGUAGE RecordWildCards            #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}

module Raft.Server where

import           Control.Distributed.Process
import           Data.Proxy
import           System.Random

import           Raft.State
import           Raft.Types

import qualified Raft.Candidate                           as Candidate
import qualified Raft.Disabled                            as Disabled
import qualified Raft.Follower                            as Follower
import qualified Raft.Leader                              as Leader

showRole :: Role -> String
showRole Candidate = "candidate"
showRole Follower = "follower"
showRole Leader = "leader"
showRole Disabled = "disabled"

clearInbox :: Process ()
clearInbox = do
  receiveTimeout 0 [matchUnknown $ pure ()] >>= \case
    Nothing -> pure ()
    Just _ -> clearInbox

-- | Runs a Raft server in environment `env` with role `role`.
run :: RaftCommand cmd => Env cmd -> Role -> Process ()
run env role = do
  t <- getTerm env
  say $ "Running in " ++ show t ++ " as " ++ showRole role
  clearInbox

  role' <-
    case role of
      Follower -> setRole env role >> Follower.run env
      Candidate -> setRole env role >> Candidate.run env
      Leader -> setRole env role >> Leader.run env
      Disabled -> Disabled.run env -- remember the previous role
  run env role'

-- | Start a Raft server with the specified environment and peers.
start ::
     RaftCommand cmd
  => Proxy cmd
  -> StdGen
  -> Config
  -> [PeerAddress]
  -> Process ()
start proxy gen config peers = do
  env <- newEnv proxy gen config peers
  run env Follower
