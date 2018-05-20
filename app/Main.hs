{-# LANGUAGE LambdaCase      #-}
{-# LANGUAGE TemplateHaskell #-}

import           Control.Distributed.Process
import           Control.Distributed.Process.Backend.SimpleLocalnet
import           Control.Distributed.Process.Node                   (initRemoteTable,
                                                                     runProcess)
import           System.Environment

import           Distributed.Bootstrap
import           Raft.Server                                        as Raft
import           Raft.Types                                         as Raft
import           Utils

run :: (RemoteTable -> RemoteTable) -> IO ()
run frtable = do
  args <- getArgs
  let rtable = frtable initRemoteTable
  case args of
    ["local", n] -> do
      backend <- initializeBackend defaultHost defaultPort rtable
      node <- newLocalNode backend
      runProcess node $ master (read n) (Raft.start defaultEnv)
    ["distributed", n, host, port] -> do
      backend <- initializeBackend host port rtable
      node <- newLocalNode backend
      nids <- findPeers backend (seconds 1)
      runProcess node $ masterless (read n) nids "raft" (Raft.start defaultEnv)
    _ ->
      putStrLn
        "Usage:\n\
        \  raft local <#nodes>\n\
        \  raft distributed <#nodes> <host> <port>"

defaultEnv :: Raft.ServerEnv
defaultEnv = Raft.ServerEnv {}

defaultHost :: String
defaultHost = "localhost"

defaultPort :: String
defaultPort = "44444"

main :: IO ()
main = run Raft.__remoteTable
