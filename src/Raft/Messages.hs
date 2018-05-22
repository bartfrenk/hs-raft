{-# LANGUAGE DeriveGeneric #-}

module Raft.Messages where

import           Data.Binary
import           Data.Typeable
import           GHC.Generics



data ElectionTimeout = ElectionTimeout
  deriving (Generic, Typeable)

instance Binary ElectionTimeout


data AppendEntries = AppendEntries
  deriving (Generic, Typeable)

instance Binary AppendEntries
