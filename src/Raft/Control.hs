{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Raft.Control
  ( start
  ) where

import           Control.Distributed.Process
import           Control.Distributed.Process.Serializable
import           Control.Monad.Trans                      (lift)
--import           Data.List                                (intercalate)
import           Data.Map.Strict                          (Map, (!?))
import qualified Data.Map.Strict                          as Map
import           System.Console.Haskeline
import Control.Monad.Except

import           Orphans                                  ()
import           Raft.Control.Parser
import qualified Raft.Messages                            as M



data Env = Env
  { peerMap    :: Map Int ProcessId
  , basePrompt :: String
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
makePrompt Env {..} = concat ["(", show $ length peerMap, ") ", basePrompt]

runRepl :: Env -> Process ()
runRepl env = do
  let settings = setComplete (fromCompletions completions) defaultSettings
  runInputT settings $ loop env
  where
    loop :: Env -> InputT Process ()
    loop env@Env {..} = do
      getInputLine (makePrompt env) >>= \case
        Nothing -> pure () >> loop env
        Just input -> do
          case parse input of
            Left _ -> outputStrLn ("unknown command: " ++ input) >> loop env
            Right Nothing -> loop env
            Right (Just Quit) -> return ()
            Right (Just cmd) -> do
              lift $ processCommand env cmd
              loop env

newControlEnv :: [ProcessId] -> Env
newControlEnv peers =
  Env {peerMap = Map.fromList $ zip [0 ..] peers, basePrompt = ">> "}

printResult :: (Show a, Show b, MonadIO m) => ExceptT a m b -> m ()
printResult act = runExceptT act >>= \case
  Left err -> liftIO $ putStrLn $ "error" ++ show err
  Right success -> liftIO $ putStrLn $ show success

processCommand :: Env -> Command -> Process ()
processCommand env (Disable idx) = printResult $ do
  pid <- lookupNode env idx
  lift $ send pid M.disable
processCommand env (Enable idx) = printResult $ do
  pid <- lookupNode env idx
  lift $ send pid M.disable
processCommand env (Inspect (Just idx)) = printResult $ do
  pid <- lookupNode env idx
  broadcastTimeout (Map.singleton idx pid) 100000 M.InspectRequest
processCommand Env{peerMap} (Inspect Nothing) = printResult $
  broadcastTimeout peerMap 1000000 M.InspectRequest
processCommand _ Quit = error "Can not process Quit command"

for :: [a] -> (a -> b) -> [b]
for = flip fmap

remove :: (a -> Bool) -> [a] -> [a]
remove pred = filter (not . pred)

lookupNode :: Monad m => Env -> Int -> ExceptT String m ProcessId
lookupNode Env{peerMap} idx =
  case peerMap !? idx of
    Nothing -> throwError ("No such node: " ++ show idx)
    Just pid -> pure $ pid

broadcastTimeout ::
     (Ord a, Serializable b, Serializable c)
  => Map a ProcessId
  -> Int
  -> (SendPort b -> c)
  -> ExceptT String Process (Map a b)
broadcastTimeout pids timeout newMsg = do
  receivePorts <- lift $ traverse (sendWithPort newMsg) pids
  responses <- lift $ receiveTaggedChans timeout (Map.toList receivePorts)
  pure $ Map.fromList responses

receiveTaggedChans :: Eq a => Int -> [(a, ReceivePort b)] -> Process [(a, b)]
receiveTaggedChans timeout = loop []
  where
    loop acc [] = pure acc
    loop acc chans = do
      let matches = for chans $ \(idx, port) ->
            (matchChan port $ \resp -> pure (idx, resp))
      receiveTimeout timeout matches >>= \case
        Just (idx, received) ->
          let remaining = remove (\t -> fst t == idx) chans
          in loop ((idx, received):acc) remaining
        Nothing -> pure acc

sendWithPort ::
     (Serializable a, Serializable b)
  => (SendPort a -> b)
  -> ProcessId
  -> Process (ReceivePort a)
sendWithPort newMsg pid = do
  (sendPort, receivePort) <- newChan
  send pid (newMsg sendPort)
  pure receivePort

start :: [ProcessId] -> Process ()
start = runRepl . newControlEnv
