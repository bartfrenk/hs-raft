{-# LANGUAGE ConstraintKinds            #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeSynonymInstances       #-}
{-# LANGUAGE UndecidableInstances       #-}

-- Maybe fix this one day
module Raft.Types where

import           Control.Distributed.Process
import           Control.Distributed.Process.Serializable
import           Data.Binary
import           GHC.Generics

data Role
  = Candidate
  | Follower
  | Leader
  | Disabled
  deriving (Eq, Show, Generic)

instance Binary Role

type PeerID = ProcessId

type PeerAddress = ProcessId

type RaftCommand cmd = (Serializable cmd, Show cmd)
