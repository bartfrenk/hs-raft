{-# LANGUAGE RecordWildCards #-}

import           Control.Distributed.Process.Backend.SimpleLocalnet
import           Control.Distributed.Process.Node                   hiding (newLocalNode)
import           Data.Semigroup                                     ((<>))
import           Options.Applicative

import           Utils.Bootstrap
import           Utils.Duration
import           Utils.Network                                      (getFreePort)

import qualified Raft.Control                                       as Control

data Settings = Settings
  { host :: !String
  , port :: !Integer
  }

parseCommandLine :: IO Settings
parseCommandLine = do
  defaultPort <- getFreePort
  execParser $ info (helper <*> parser defaultPort) fullDesc
  where
    parser defaultPort =
      Settings <$> strOption (long "host" <> short 'h' <> value "localhost") <*>
      option auto (long "port" <> short 'p' <> value defaultPort)

run :: Settings -> IO ()
run Settings {..} = do
  backend <- initializeBackend "localhost" "44444" initRemoteTable
  node <- newLocalNode backend
  nids <- findPeers backend 1000000
  runProcess node $ client nids "raft" (milliseconds 100) $ Control.start

main :: IO ()
main = do
  parseCommandLine >>= run
