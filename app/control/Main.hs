import           Control.Distributed.Process.Backend.SimpleLocalnet
import           Control.Distributed.Process.Node hiding (newLocalNode)

import           Utils.Duration
import           Utils.Bootstrap

import qualified Raft.Control as Control

main :: IO ()
main = do
  backend <- initializeBackend "localhost" "44444" initRemoteTable
  node <- newLocalNode backend
  nids <- findPeers backend 1000000
  runProcess node $ client nids "raft" (milliseconds 100) $ Control.start


