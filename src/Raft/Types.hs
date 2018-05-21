{-# LANGUAGE ConstraintKinds            #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE TypeSynonymInstances       #-}
-- Maybe fix this one day
{-# LANGUAGE UndecidableInstances       #-}

module Raft.Types where

import           Control.Distributed.Process              (Process, ProcessId)
import           Control.Distributed.Process.Lifted.Class
import           Control.Monad.Base
import           Control.Monad.Reader
import           Control.Monad.State                      (MonadState, StateT,
                                                           evalStateT)
import           Control.Monad.Trans.Control
import           Utils

newtype Term =
  Term Int

type ServerId = ProcessId

-- | Server environment with parameters for the server that do not change at
-- runtime, e.g. delay and timeout settings.
data ServerEnv = ServerEnv
  { electionTimeout :: RandomVar Int
  }

data Role
  = Candidate
  | Follower
  | Leader
  deriving (Eq, Show)

data ServerState = ServerState
  { currentTerm :: Term
  , votedFor    :: Maybe ServerId
  , role        :: Role
  , peers       :: [ServerId]
  }

type MonadServer m
   = ( MonadProcess m
     , MonadRandom Int m
     , MonadProcessBase m
     , MonadState ServerState m
     , MonadReader ServerEnv m)

newtype ServerM a = ServerM
  { unServerM :: StateT ServerState (ReaderT ServerEnv Process) a
  } deriving ( Functor
             , Applicative
             , Monad
             , MonadState ServerState
             , MonadReader ServerEnv
             , MonadBase IO
             , MonadBaseControl IO
             , MonadProcess
             , MonadProcessBase
             , MonadIO
             )

instance MonadRandom Int ServerM where
  sample = liftIO . sample

evalServer :: ServerM a -> ServerState -> ServerEnv -> Process a
evalServer (ServerM server) state env = runReaderT (evalStateT server state) env
