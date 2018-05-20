{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase                 #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}

module Raft.Server where

import           Control.Distributed.Process.Closure
import           Control.Distributed.Process.Lifted

import           Data.Binary
import           Data.Typeable

import           Control.Monad.State
import           Raft.Types
import           Utils

newtype Pids =
  Pids [ProcessId]
  deriving (Typeable, Binary, Show)

server :: MonadServer m => m ()
server = say "starting server" >> loop
  where
    loop = do
      gets role >>= \case
        Candidate -> candidate
        Follower -> follower
        Leader -> leader
      loop

candidate :: MonadServer m => m ()
candidate = do
  gets role >>= say . show >> delay 1000 milliseconds

follower :: MonadServer m => m ()
follower = do
  gets role >>= say . show >> delay 1000 milliseconds

leader :: MonadServer m => m ()
leader = gets role >>= say . show >> delay 1000 milliseconds

initialState :: ServerState
initialState =
  ServerState
  {currentTerm = initialTerm, votedFor = Nothing, role = Follower, peers = []}

initialTerm :: Term
initialTerm = Term 0

-- | Start a Raft server with the specified environment and peers.
start :: ServerEnv -> [ProcessId] -> Process ()
start env peers =
  evalServer (setPeers >> server) initialState env
  where setPeers = modify $ \state -> state {peers = peers}

remotable ['start]
