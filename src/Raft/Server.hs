{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE TemplateHaskell #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}

module Raft.Server where

import Control.Monad.Cont
import Control.Distributed.Process.Closure
import Control.Distributed.Process.Lifted
import Control.Distributed.Process.Lifted.Class
import Control.Monad.Reader
import Control.Monad.State
import Data.Binary
import Data.Typeable
import Control.Lens

import qualified Distributed.Timer as Timer

import Raft.Messages
import Raft.Types
import Utils

newtype Pids =
  Pids [ProcessId]
  deriving (Typeable, Binary, Show)

server :: MonadServer m => m ()
server = say "starting server" >> loop
  where
    loop = do
      use role >>= \case
        Candidate -> candidate
        Follower -> follower
        Leader -> leader
      loop

candidate :: MonadServer m => m ()
candidate = do
  bracket startElectionTimer Timer.cancel loop
  where
    loop timer =
      whenM (hasRole Candidate) $ handle timer loop

    handle :: MonadServer m => Timer.Ref -> (Timer.Ref -> m ()) -> m ()
    handle timer cont = controlP $
      \run -> receiveWait [ match $ run . (handleElectionTimeout timer cont)
                          ]

handleElectionTimeout :: MonadServer m => Timer.Ref -> (Timer.Ref -> m ()) -> ElectionTimeout -> m ()
handleElectionTimeout timer cont _ = pure ()


startElectionTimer :: MonadServer m => m Timer.Ref
startElectionTimer = do
  ms <- reader electionTimeout >>= sample
  pid <- getSelfPid
  say $ "starting timer: " ++ show ms
  Timer.start [ms] pid ElectionTimeout

handleHeartbeatTimeout :: MonadServer m => ElectionTimeout -> m ()
handleHeartbeatTimeout _ = role .= Candidate

handleAppendEntries :: MonadServer m => Timer.Ref -> AppendEntries -> m ()
handleAppendEntries timer _ = Timer.reset timer

hasRole :: MonadState ServerState m => Role -> m Bool
hasRole r = ((==) r) `fmap` use role

whenM :: Monad m => m Bool -> m () -> m ()
whenM prop' act = do
  prop <- prop'
  when prop act

follower :: MonadServer m => m ()
follower = bracket startElectionTimer Timer.cancel loop
  where
    loop timer =
      whenM (hasRole Follower) (handle timer >> loop timer)

    handle :: MonadServer m => Timer.Ref -> m ()
    handle timer = controlP $
      \run -> receiveWait [ match $ run . handleHeartbeatTimeout
                          , match $ run . handleAppendEntries timer
                          ]

leader :: MonadServer m => m ()
leader = use role >>= say . show >> delay (milliseconds 1000)

initialState :: ServerState
initialState =
  ServerState
  {_currentTerm = initialTerm, _votedFor = Nothing, _role = Follower, _peers = []}

initialTerm :: Term
initialTerm = Term 0

-- | Start a Raft server with the specified environment and peers.
start :: ServerEnv -> [ProcessId] -> Process ()
start env peers = evalServer (setPeers >> server) initialState env
  where
    setPeers = modify $ \state -> state {_peers = peers}

--remotable ['start]
