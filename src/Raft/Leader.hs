module Raft.Leader where

import Control.Monad.Catch
import Control.Distributed.Process hiding (bracket)

import qualified Utils.Timer as T

import Raft.Messages
import Raft.State
import Raft.Types
import Raft.Shared

startHeartbeatTicker :: Env -> Process T.Ref
startHeartbeatTicker env = do
  dt <- getHeartbeatInterval env
  say $ "Heartbeat interval: " ++ show dt
  pid <- getSelfPid
  T.startTicker dt pid T.Tick

run :: Env -> Process Role
run env = bracket (startHeartbeatTicker env) T.cancelTimer $ loop
  where loop timer = do
          status <- receiveWait
            [ match $ processBallot env ()
            , match $ processTicker env
            , match $ processAppendEntries env ()
            , match $ processAppendEntriesResp env ()
            , match $ processControl env ()
            , match $ processInspectRequest env ()
            ]
          case status of
            InProgress () -> loop timer
            Superseded -> pure Follower
            Timeout -> loop timer -- should not happen
            Controlled Disable -> pure Disabled
            Controlled _ -> loop timer


processTicker :: Env -> T.Tick -> Process (Status ())
processTicker env _ = do
  t <- getTerm env
  msg <- AppendEntries t <$> getSelfAddress env
  mapM_ (flip send msg) =<< getPeers env
  pure $ InProgress ()

processAppendEntries :: Env -> a -> AppendEntries -> Process (Status a)
processAppendEntries env x msg = do
  t <- getTerm env
  let t' = term (msg :: AppendEntries)
  if t' <= t -- Note that the candidate is superseded when t = t'
    then pure $ InProgress x
    else setTerm env t' >> pure Superseded



