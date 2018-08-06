{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Raft.Messages where

import           Control.Distributed.Process (SendPort, ProcessId)
import           Data.Binary
import           Data.Typeable
import           GHC.Generics

import           Raft.Types

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


data Command =
  Disable | Enable
  deriving (Generic, Show, Typeable)

instance Binary Command

data Control = Control
  { command :: Command
  } deriving (Generic, Show, Typeable)

instance Binary Control

data InspectRequest = InspectRequest
  { sendPort :: SendPort InspectReply
  } deriving (Generic, Show, Typeable)

instance Binary InspectRequest

data InspectReply = InspectReply
  { role :: Role
  , term :: Int
  , votedFor :: Maybe ProcessId
  } deriving (Generic, Show, Typeable)

instance Binary InspectReply

disable :: Control
disable = Control Disable

enable :: Control
enable = Control Enable
