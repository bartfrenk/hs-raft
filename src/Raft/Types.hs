{-# LANGUAGE ConstraintKinds  #-}
{-# LANGUAGE DeriveGeneric    #-}
{-# LANGUAGE FlexibleContexts #-}

module Raft.Types where

import           Control.Distributed.Process              (Process, ProcessId)
import           Control.Distributed.Process.Lifted.Class
import           Control.Monad.Reader
import           Control.Monad.State                      (MonadState, StateT,
                                                           evalStateT)
import           Data.Binary                              (Binary)
import           Data.Typeable
import           GHC.Generics                             (Generic)

newtype Term =
  Term Int

type ServerId = ProcessId

-- | Server environment with parameters for the server that do not change at
-- runtime, e.g. delay and timeout settings.
data ServerEnv = ServerEnv
  {
  } deriving (Generic, Typeable)

instance Binary ServerEnv

data Role
  = Candidate
  | Follower
  | Leader
  deriving (Show)

data ServerState = ServerState
  { currentTerm :: Term
  , votedFor    :: Maybe ServerId
  , role        :: Role
  , peers       :: [ServerId]
  }

type MonadServer m
   = (MonadProcess m, MonadState ServerState m, MonadReader ServerEnv m)

type ServerM a = StateT ServerState (ReaderT ServerEnv Process) a

evalServer :: ServerM a -> ServerState -> ServerEnv -> Process a
evalServer server state env = runReaderT (evalStateT server state) env
