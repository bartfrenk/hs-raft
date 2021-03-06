{-# LANGUAGE DeriveGeneric #-}

module Utils.Bootstrap
  ( masterless
  , master
  , client
  ) where

import           Control.Distributed.Process hiding (bracket)
import           Control.Monad
import           Control.Monad.Catch
import           Data.Binary
import           Data.Maybe
import           Data.Typeable
import           GHC.Generics

import           Utils.Duration
import qualified Utils.Timer                 as T

-- | Starts the process `cont` and passes it the process IDs of all processes
-- registered under `name` on any of the specified nodes. First waits until
-- there are exactly `n` such registered processes.
masterless ::
     Int -> [NodeId] -> String -> ([ProcessId] -> Process a) -> Process a
masterless n nids name cont = do
  self <- getSelfPid
  register name self
  void (forM nids $ flip whereisRemoteAsync name)
  loop self [self] >>= cont
  where
    loop self knownPids
      | length knownPids == n = pure knownPids
      | otherwise = do
          WhereIsReply name' mpid <- expect
          case mpid of
            Just pid ->
              if (pid `elem` knownPids) || (name /= name')
              then loop self knownPids
              else do
                send pid $ WhereIsReply name $ Just self
                loop self (pid : knownPids)
            Nothing -> loop self knownPids

data GetSlaves =
  GetSlaves ProcessId
  deriving (Generic, Typeable)

instance Binary GetSlaves

data GetSlavesReply =
  GetSlavesReply [ProcessId]
  deriving (Generic, Typeable)

instance Binary GetSlavesReply

-- | Spawns `n` copies of `cont` locally, and passes the process identifiers to
-- each of these copies.
master :: Int -> String -> ([ProcessId] -> Process ()) -> Process ()
master n name cont = do
  pids <- replicateM n $ spawnLocal (expect >>= cont)
  getSelfPid >>= register name
  forM_ pids $ flip send pids
  loop pids
  where
    loop pids = do
      GetSlaves sender <- expect
      send sender $ GetSlavesReply pids
      loop pids

-- | Learns the process IDs of all services registered under `name` on the nodes
-- identified by the identifiers `nids`, and passes these to `cont`.
client ::
     [NodeId] -> String -> Duration -> ([ProcessId] -> Process a) -> Process a
client nids name timeout cont =
  bracket startTimer T.cancelTimer $ \timer -> do
    void (forM nids $ flip whereisRemoteAsync name)
    pids <- loop timer []
    cont pids
  where
    startTimer = do
      pid <- getSelfPid
      T.startTimer timeout pid T.Tick
    loop timer knownPids = do
      result <-
        receiveWait
          [ match $ \(WhereIsReply name' mpid) -> do
              if name == name'
                then pure $ Just $ maybeToList mpid
                else pure $ Just []
          , match $ \T.Tick -> pure $ Nothing
          ]
      case result of
        Just pids -> loop timer (knownPids ++ pids)
        Nothing ->
          if | length knownPids == 1 ->
               let [masterPid] = knownPids
               in do (send masterPid . GetSlaves) =<< getSelfPid
                     GetSlavesReply pids <- expect
                     pure pids
             | otherwise -> pure knownPids
