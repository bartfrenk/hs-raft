{-# LANGUAGE LambdaCase      #-}
{-# LANGUAGE TemplateHaskell #-}

import           Control.Distributed.Process
import           Control.Distributed.Process.Backend.SimpleLocalnet
import           Control.Distributed.Process.Node hiding (newLocalNode)
import           System.Environment
import           System.Random (newStdGen)

import           Utils.Duration
import           Utils.Bootstrap

import           Raft


config :: Config
config = defaultConfig
  { electionTimeout = (seconds 2, seconds 4) }

run :: (RemoteTable -> RemoteTable) -> IO ()
run frtable = do
  args <- getArgs
  let rtable = frtable initRemoteTable
  g <- newStdGen
  case args of
    ["local", n] -> do
      backend <- initializeBackend defaultHost defaultPort rtable
      node <- newLocalNode backend
      runProcess node $ master (read n) (start g config)
    ["distributed", n, host, port] -> do
      backend <- initializeBackend host port rtable
      node <- newLocalNode backend
      nids <- findPeers backend (seconds 1)
      runProcess node $ masterless (read n) nids "raft" (start g config)
    _ ->
      putStrLn
        "Usage:\n\
        \  raft local <#nodes>\n\
        \  raft distributed <#nodes> <host> <port>"
  where
    seconds = (* 1000000)

defaultHost :: String
defaultHost = "localhost"

defaultPort :: String
defaultPort = "44444"

main :: IO ()
main = run id
