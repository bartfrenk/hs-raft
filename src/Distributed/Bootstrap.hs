module Distributed.Bootstrap where

import Control.Distributed.Process
import Control.Monad

type Peer a = [ProcessId] -> Process a

-- | Starts the process `cont` and passes it the process IDs of all processes
-- registered under `name` on any of the specified nodes. Waits until there are
-- exactly `n` such processes.
masterless :: Int -> [NodeId] -> String -> ([ProcessId] -> Process a) -> Process a
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

-- | Spawns `n` copies of `cont` locally, and passes the process identifiers to
-- each of these copies.
master :: Int -> Peer () -> Process ()
master n cont = do
  pids <- replicateM n $ spawnLocal (expect >>= cont)
  forM_ pids $ flip send pids
  loop
  where
    loop = loop


test :: IO Int
test = pure 5

bla :: IO Int
bla = test
