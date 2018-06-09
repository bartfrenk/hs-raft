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

import Control.Distributed.Process

data Role = Candidate | Follower | Leader
  deriving (Eq, Show)

type PeerID = ProcessId

type PeerAddress = ProcessId
