{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TemplateHaskell #-}

import           Control.Distributed.Process
import           Control.Distributed.Process.Backend.SimpleLocalnet
import           Control.Distributed.Process.Node                   hiding (newLocalNode)
import           Data.Proxy
import           Data.Semigroup                                     ((<>))
import           Options.Applicative
import           System.Random

import           Utils.Bootstrap
import           Utils.Duration
import           Utils.Network                                      (getFreePort)

import           Raft

raftConfig :: Raft.Config
raftConfig =
  defaultConfig
  { electionTimeout = (milliseconds 1000, milliseconds 2000)
  , heartbeatInterval = milliseconds 200
  }

data Settings = Settings
  { nodeCount  :: !Int
  , host       :: !String
  , port       :: !Integer
  , isLocalRun :: !Bool
  }

parseCommandLine :: IO Settings
parseCommandLine = do
  defaultPort <- getFreePort
  execParser $ info (helper <*> parser defaultPort) desc
  where
    desc = fullDesc
    parser defaultPort =
      Settings <$>
      option auto (short 'n' <> help "Total number of raft instances") <*>
      strOption (long "host" <> short 'h' <> value "localhost") <*>
      option auto (long "port" <> short 'p' <> value defaultPort) <*>
      switch (long "local" <> help "Run all Raft instances in the same process")

-- | Determines the type of the commands that started Raft instances accept.
cmdProxy :: Proxy String
cmdProxy = Proxy

-- | Run a single Raft instance on a freshly created local node.
runDistributed :: Settings -> IO ()
runDistributed Settings {..} = do
  backend <- initializeBackend host (show port) initRemoteTable
  node <- newLocalNode backend
  nids <- liftIO $ findPeers backend 1000000
  g <- liftIO $ newStdGen
  runProcess node (process nids g)
  where
    process nids g = do
      masterless nodeCount nids "raft" (start cmdProxy g raftConfig)

runLocal :: Settings -> IO ()
runLocal Settings {..} = do
  backend <- initializeBackend host (show port) initRemoteTable
  node <- newLocalNode backend
  runProcess node process
  where
    process =
      master nodeCount "raft" $ \peers -> do
        g <- liftIO $ mkStdGen <$> randomIO -- different timeouts required at each node
        start cmdProxy g raftConfig peers

-- | Start one, or more Raft instances, depending on the settings.
run :: Settings -> IO ()
run settings = do
  if | isLocalRun settings -> runLocal settings
     | otherwise -> runDistributed settings

main :: IO ()
main = parseCommandLine >>= run
