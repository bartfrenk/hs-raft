{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DuplicateRecordFields #-}
module Raft.Shared where

import Control.Monad.Trans (MonadIO)
import Control.Monad
import Control.Distributed.Process

import Raft.Messages
import Raft.State

data Status a
  = Timeout -- ^ The election has timed out.
  | Superseded -- ^ A message from the future has been received
  | InProgress a -- ^ The election is still in progress
  | Controlled Command -- ^ A control command has been received
  deriving (Show)

checkTerm :: Env cmd -- ^ The server's state and configuration
          -> Int -- ^ Term in the received message
          -> Process (Status a) -- ^ Action when message is from past or present
          -> Process () -- ^ Action when message is from the future
          -> Process (Status a)
checkTerm env term cont superseded = do
  t <- getTerm env
  if term <= t
    then cont
    else setTerm env term >> superseded >> pure Superseded


newAppendEntriesResp :: MonadIO m => Env cmd -> AppendEntries cmd -> m AppendEntriesResp
newAppendEntriesResp env _ = do
  tm <- getTerm env
  pure $ AppendEntriesResp { aerTerm = tm }

processBallot :: Env cmd -> a -> Ballot -> Process (Status a)
processBallot env x msg = do
  let t' = term msg
  t <- getTerm env
  case t' `compare` t of
    LT -> do
      -- Candidate is behind. Do not grant vote.
      let vote = Vote { granted = False, vTerm = t' }
      sendChan (sendPort (msg :: Ballot)) vote
      pure $ InProgress x
    EQ -> sendVote t >> (pure $ InProgress x)
    GT -> do
      setTerm env t' -- fresh term without existing vote
      sendVote t >> (pure $ Superseded)
  where
    sendVote :: Int -> Process ()
    sendVote t = do
      -- TODO: While strictly not necessary due to the Raft server being single
      -- threaded, it is probably better to make reading and setting the vote atomic.
      p <- hasVoted env
      when (not p) $ voteFor env $ candidateID msg
      tm <- getTerm env
      say $ "Vote for " ++ show (candidateID msg) ++ " in " ++ show tm ++ ": " ++ show (not p)
      let vote = Vote { granted = not p, vTerm = t }
      sendChan (sendPort (msg :: Ballot)) vote

processAppendEntriesResp :: Env cmd -> a -> AppendEntriesResp -> Process (Status a)
processAppendEntriesResp env x msg =
  let t = term (msg :: AppendEntriesResp)
  in checkTerm env t (pure $ InProgress x) (pure ())

processControl :: Env cmd -> a -> Control -> Process (Status a)
processControl _ _ (Control cmd) = pure $ Controlled cmd

processInspectRequest :: Env cmd -> a -> InspectRequest -> Process (Status a)
processInspectRequest env x msg = do
  role <- getRole env
  term <- getTerm env
  votedFor <- hasVotedFor env
  logTerms <- getLogTerms env
  let reply = InspectReply
        { role = role
        , irTerm = term
        , votedFor = votedFor
        , logTerms = logTerms
        }
  sendChan (sendPort (msg :: InspectRequest)) reply
  pure $ InProgress x
