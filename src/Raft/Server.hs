{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE TemplateHaskell #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}

module Raft.Server where

import Control.Distributed.Process.Closure
import Control.Distributed.Process.Lifted
import Control.Distributed.Process.Lifted.Class
import Control.Monad.Reader
import Control.Monad.State
import Data.Binary
import Data.Typeable

import Distributed.Timer

import Raft.Messages
import Raft.Types
import Utils

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

startElectionTimer :: MonadServer m => m TimerRef
startElectionTimer = do
  ms <- reader electionTimeout >>= sample
  pid <- getSelfPid
  say $ "starting timer: " ++ show ms
  startTimer [ms] pid ElectionTimeout

handleElectionTimeout :: MonadServer m => ElectionTimeout -> m ()
handleElectionTimeout _ = do
  say "asdasasd"
  modify $ \state -> state {role = Candidate}

hasRole :: MonadState ServerState m => Role -> m Bool
hasRole r = ((==) r) `fmap` gets role

whenM :: Monad m => m Bool -> m () -> m ()
whenM prop' act = do
  prop <- prop'
  when prop act

follower :: MonadServer m => m ()
follower = startElectionTimer >> loop
  where
    loop :: MonadServer m => m ()
    loop = do
      whenM (hasRole Follower) $ do
        controlP $ \run -> receiveWait [match $ run . handleElectionTimeout]
      -- TODO: understand and clean up
      whenM (hasRole Follower) $ do
        loop

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
start env peers = evalServer (setPeers >> server) initialState env
  where
    setPeers = modify $ \state -> state {peers = peers}
--remotable ['start]
