{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Raft.Messages where

import           Control.Distributed.Process (SendPort)
import           Data.Binary
import           Data.Typeable
import           GHC.Generics

import           Raft.Types

data Tick = Tick
  deriving (Generic, Typeable)

instance Binary Tick

data AppendEntries = AppendEntries
  { term :: Int
  }
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

data Vote = Vote
  { term :: Int
  , granted :: Bool
  } deriving (Generic, Show, Typeable)

instance Binary Vote

data Ballot = Ballot
  { term :: Int
  , candidateID :: PeerID
  , sendPort :: SendPort Vote
  } deriving (Generic, Show, Typeable)

instance Binary Ballot


