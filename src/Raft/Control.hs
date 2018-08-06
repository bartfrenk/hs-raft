{-# LANGUAGE RecordWildCards #-}

module Raft.Control
  ( start
  ) where

import           Control.Distributed.Process
import           Control.Monad.Trans         (lift)
import           Data.Map.Strict             (Map, (!?))
import qualified Data.Map.Strict             as Map
import           System.Console.Haskeline

import           Orphans                     ()
import           Raft.Control.Parser
import qualified Raft.Messages               as M

data Env = Env
  { peerMap :: Map Int ProcessId
  , basePrompt  :: String
  }

completions :: [String]
completions = ["\\disable", "\\enable", "\\inspect", "\\quit"]

isPrefixOf :: Eq a => [a] -> [a] -> Bool
isPrefixOf [] _ = True
isPrefixOf _ [] = False
isPrefixOf (p:ps) (w:ws)
  | p == w = isPrefixOf ps ws
  | otherwise = False

fromCompletions :: Monad m => [String] -> CompletionFunc m
fromCompletions cs = completeWord Nothing " \t" (pure . fn)
  where
    fn s = simpleCompletion <$> (isPrefixOf s `filter` cs)

makePrompt :: Env -> String
makePrompt Env{..} = concat ["(", show $ length peerMap, ") ", basePrompt]

run' :: Env -> Process ()
run' env = do
  let settings = setComplete (fromCompletions completions) defaultSettings
  runInputT settings $ loop env
  where
    loop :: Env -> InputT Process ()
    loop env@Env {..} = do
      getInputLine (makePrompt env) >>= \case
        Nothing -> return () >> loop env
        Just input -> do
          case parse input of
            Left _ -> outputStrLn ("unknown command: " ++ input) >> loop env
            Right Nothing -> loop env
            Right (Just Quit) -> return ()
            Right (Just cmd) -> do
              lift $
                processCommand env cmd >>= \case
                  Left err -> liftIO $ putStrLn $ "error: " ++ err
                  Right success -> liftIO $ putStrLn success
              loop env

newControlEnv :: [ProcessId] -> Env
newControlEnv peers =
  Env {peerMap = Map.fromList $ zip [0 ..] peers, basePrompt = ">> "}

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
      pure $
        Right ("sent control command " ++ show msg ++ " to node " ++ show idx)

start :: [ProcessId] -> Process ()
start = run' . newControlEnv
