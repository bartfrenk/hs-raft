{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Raft.Messages where

import           Control.Distributed.Process (SendPort)
import           Data.Binary
import           Data.Typeable
import           GHC.Generics

import           Raft.Types

data ElectionTimeout =
  ElectionTimeout
  deriving (Generic, Typeable)

instance Binary ElectionTimeout

data AppendEntries =
  AppendEntries
  deriving (Generic, Typeable)

instance Binary AppendEntries

data VoteRequest = VoteRequest
  { term        :: Term
  , candidateId :: ServerId
  , sendPort    :: SendPort VoteResponse
  } deriving (Generic, Show, Typeable)

instance Binary VoteRequest

data VoteResponse = VoteResponse
  { term        :: Term
  , voteGranted :: Bool
  } deriving (Generic, Show, Typeable)

instance Binary VoteResponse
