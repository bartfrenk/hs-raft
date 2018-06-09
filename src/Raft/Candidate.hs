{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE RecordWildCards #-}

module Raft.Candidate where

import Control.Monad.Catch
import Control.Distributed.Process hiding (bracket)

import qualified Utils.Timer as T
import Raft.Messages
import Raft.State
import Raft.Types
import Raft.Shared

data Election = Election
  { pending :: [ReceivePort Vote]
  , nReceived :: Int
  , nGranted :: Int
  , nPeers :: Int
  }

data Result = Loss | Win | Inconclusive

result :: Election -> Result
result Election{..} = let threshold = (nPeers `div` 2) + 1
         in if nGranted >= threshold
            then Win
            else if nGranted + (nPeers - nReceived) < threshold
                 then Loss
                 else Inconclusive

processVote :: Env -> Election -> Vote -> Process (Status Election)
processVote env e vote = do
  t <- getTerm env
  let t' = term (vote :: Vote)
  if t' <= t
    then pure $ InProgress $
         if granted vote
           then e { nReceived = nReceived e + 1, nGranted = nGranted e + 1 }
           else e { nReceived = nReceived e + 1, nGranted = nGranted e }
    else setTerm env t' >> pure Superseded

processTimeout :: Tick -> Process (Status Election)
processTimeout _ = pure Timeout

processAppendEntries :: Env -> a -> AppendEntries -> Process (Status a)
processAppendEntries env x msg = do
  t <- getTerm env
  let t' = term (msg :: AppendEntries)
  if t' < t -- Note that the candidate is superseded when t = t'
    then pure $ InProgress x
    else setTerm env t' >> pure Superseded

-- | Starts the timer that sends a @Tick@ message to indicate that the election
-- timed out.
startElectionTimer :: Env -> Process T.Ref
startElectionTimer env = do
  d <- drawElectionTimeout env
  say $ "Election timeout: " ++ show d
  pid <- getSelfPid
  T.startTimer d pid Tick

-- | Runs the server in the `candidate` role. The return value of this function
-- is the new role to assume.
run :: Env -> Process Role
run env = bracket (startElectionTimer env) T.cancelTimer $ \_ -> do
  incTerm env
  e <- sendBallots
  awaitVotes e

  where

    awaitVotes e = do
      let matchPending =
            flip matchChan (processVote env e) <$> pending e

      status <- receiveWait $
        (match $ processAppendEntries env e):
        (match $ processBallot env e):
        (match $ processTimeout):
         matchPending

      case status of
        InProgress e -> case result e of
          Loss -> pure Follower
          Win -> pure Leader
          Inconclusive -> awaitVotes e
        Timeout -> pure Candidate
        Superseded -> pure Follower

    sendBallots = do
      t <- getTerm env
      selfID <- getSelfID env
      pending <- mapM (sendSingleBallot t selfID) =<< getPeers env
      pure $ Election
        { pending = pending
        , nReceived = 1
        , nGranted = 1 -- vote for self
        , nPeers = length pending + 1 -- @getPeers@ returns only others
        }

    sendSingleBallot t selfID peer = do
      (s, r) <- newChan
      let ballot =
            Ballot { term = t, candidateID = selfID, sendPort = s }
      send peer ballot
      pure r
