module Raft.Control where

import Control.Distributed.Process
import Control.Monad
import Control.Monad.Trans (MonadIO)
import Data.Map.Strict (Map, (!?))
import qualified Data.Map.Strict as Map
import System.IO

import Raft.Types
import qualified Raft.Messages as M
import Raft.Control.Parser

data Env = Env
  { peerMap :: Map Int PeerAddress
  , prompt :: String
  }

newControlEnv :: [PeerAddress] -> Env
newControlEnv peers =
  Env {peerMap = Map.fromList $ zip [0 ..] peers, prompt = ">> "}

run :: Env -> Process ()
run env = do
  liftIO $ putStrLn $ "Client connected to peers: " ++ show (peerMap env)
  repl env
  where
    repl env = do
      liftIO $ (putStr "> " >> hFlush stdout)
      mCmd <- readInput env
      case mCmd of
        Right cmd -> do
          unless (cmd == Quit) $ do
            result <- processCommand env cmd
            case result of
              Left err -> liftIO $ putStrLn $ "error: " ++ err
              Right success -> liftIO $ putStrLn success
            repl env
        Left (err, input) -> do
          liftIO $ putStrLn $ "Failed to parse: " ++ input ++ " (" ++ show err ++ ")"
          repl env

readInput :: MonadIO m => Env -> m (Either (ParseError, String) Command)
readInput _ = do
  s <- liftIO $ getLine
  case parse s of
    Left err -> pure $ Left (err, s)
    Right cmd -> pure $ Right cmd

processCommand :: Env -> Command -> Process (Either String String)
processCommand env (Disable idx) = sendToNode env idx M.disable
processCommand env (Enable idx) = sendToNode env idx M.enable
processCommand env (Inspect idx) = sendToNode env idx M.inspect
processCommand _ Quit = pure $ Right ""

sendToNode :: Env -> Int -> M.Control -> Process (Either String String)
sendToNode env idx msg =
  case peerMap env !? idx of
    Nothing -> pure $ Left ("no such node: " ++ show idx)
    Just pid -> do
      send pid msg
      pure $ Right ("sent control command " ++ show msg ++ " to node " ++ show idx)



start :: [PeerAddress] -> Process ()
start = run . newControlEnv
