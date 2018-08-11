{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE RecordWildCards       #-}

module Raft.Messages where

import           Control.Distributed.Process (ProcessId, SendPort)
import           Data.Binary
import           Data.Sequence               (Seq)
import           Data.Text.Prettyprint.Doc
import           Data.Typeable
import           GHC.Generics

import           Raft.Types

data SubmitCommand cmd = SubmitCommand
  { cmd    :: cmd
  , sender :: ProcessId
  } deriving (Generic, Typeable)

instance Binary cmd => Binary (SubmitCommand cmd)

class HasTerm msg where
  term :: msg -> Int

data AppendEntries cmd = AppendEntries
  { aeTerm       :: Int
  , aeSender     :: PeerAddress
  , prevLogIndex :: Int
  , prevLogTerm  :: Maybe Int
  , entries      :: Seq (Int, cmd)
  , leaderCommit :: Int
  } deriving (Generic, Typeable)

instance HasTerm (AppendEntries cmd) where
  term = aeTerm

instance Binary cmd => Binary (AppendEntries cmd)

data AppendEntriesResp = AppendEntriesResp
  { aerTerm :: Int
  } deriving (Generic, Typeable)

instance HasTerm AppendEntriesResp where
  term = aerTerm

instance Binary AppendEntriesResp

data Vote = Vote
  { vTerm   :: Int
  , granted :: Bool
  } deriving (Generic, Show, Typeable)

instance HasTerm Vote where
  term = vTerm

instance Binary Vote

data Ballot = Ballot
  { bTerm       :: Int
  , candidateID :: PeerID
  , sendPort    :: SendPort Vote
  } deriving (Generic, Show, Typeable)

instance Binary Ballot

instance HasTerm Ballot where
  term = bTerm

data Command
  = SetRole Role
  | Enable
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

instance Pretty InspectReply where
  pretty msg@InspectReply {..} =
    let votedForDoc =
          case votedFor of
            Just pid -> viaShow pid
            Nothing -> "NotVoted"
    in pretty (term msg) <+> viaShow role <+> votedForDoc <+> viaShow logTerms

data InspectReply = InspectReply
  { role     :: Role
  , irTerm   :: Int
  , votedFor :: Maybe ProcessId
  , logTerms :: Seq Int
  } deriving (Generic, Show, Typeable)

instance Binary InspectReply

instance HasTerm InspectReply where
  term = irTerm

disable :: Control
disable = Control (SetRole Disabled)

enable :: Control
enable = Control Enable

setRole :: Role -> Control
setRole = Control . SetRole
