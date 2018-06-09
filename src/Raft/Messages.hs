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
  , sender :: PeerAddress
  }
  deriving (Generic, Typeable)

instance Binary AppendEntries

data AppendEntriesResp = AppendEntriesResp
  { term :: Int
  } deriving (Generic, Typeable)

instance Binary AppendEntriesResp

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


