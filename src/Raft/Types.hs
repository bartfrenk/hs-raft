{-# LANGUAGE ConstraintKinds            #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeSynonymInstances       #-}
{-# LANGUAGE UndecidableInstances       #-}

-- Maybe fix this one day
module Raft.Types where

import           Control.Distributed.Process              (Process, ProcessId)
import           Control.Distributed.Process.Lifted.Class
import           Control.Lens
import           Control.Monad.Base
import           Control.Monad.Reader
import           Control.Monad.State                      (MonadState, StateT,
                                                           evalStateT)
import           Control.Monad.Trans.Control
import           Data.Binary
import           Data.Typeable
import           Utils

newtype Term =
  Term Int
  deriving (Binary, Eq, Ord, Typeable, Show)

increment :: Term -> Term
increment (Term n) = Term $ n + 1

type ServerAddress = ProcessId

type ServerId = ProcessId

-- | Server environment with parameters for the server that do not change at
-- runtime, e.g. delay and timeout settings.
data ServerEnv = ServerEnv
  { electionTimeout :: RandomVar Duration
  }

data Role
  = Candidate
  | Follower
  | Leader
  deriving (Eq, Show)

data ServerState = ServerState
  { _currentTerm :: Term
  , _votedFor    :: Maybe ServerId
  , _role        :: Role
  , _peers       :: [ServerAddress]
  }

makeLenses ''ServerState

type MonadServer m
   = ( MonadProcess m
     , MonadRandom Duration m
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

instance MonadRandom Duration ServerM where
  sample = liftIO . sample

evalServer :: ServerM a -> ServerState -> ServerEnv -> Process a
evalServer (ServerM server) state env = runReaderT (evalStateT server state) env
