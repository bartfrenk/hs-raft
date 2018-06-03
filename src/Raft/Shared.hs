{-# LANGUAGE DuplicateRecordFields #-}
module Raft.Shared where

import Control.Monad
import Control.Distributed.Process

import Raft.Messages
import Raft.State

data Status a
  = Timeout -- ^ The election has timed out.
  | Superseded -- ^ A message from the future has been received
  | InProgress a -- ^ The election is still in progress

checkTerm :: Env -- ^ The server's state and configuration
          -> Int -- ^ Term in the received message
          -> Process (Status a) -- ^ Action when message is from past or present
          -> Process () -- ^ Action when message is from the future
          -> Process (Status a)
checkTerm env term cont superseded = do
  t <- getTerm env
  if term <= t
    then cont
    else setTerm env term >> superseded >> pure Superseded

processBallot :: Env -> a -> Ballot -> Process (Status a)
processBallot env x msg = do
  let t' = term (msg :: Ballot)
  t <- getTerm env
  case t' `compare` t of
    LT -> do
      -- Candidate is behind. Do not grant vote.
      let vote = Vote { granted = False, term = t' }
      sendChan (sendPort (msg :: Ballot)) vote
      pure $ InProgress x
    EQ -> sendVote t >> (pure $ InProgress x)
    GT -> sendVote t >> (pure $ Superseded)
  where
    sendVote :: Int -> Process ()
    sendVote t = do
      -- TODO: While strictly not necessary due to the Raft server being single
      -- threaded, it is probably better to make reading and setting the vote atomic.
      p <- hasVoted env
      when (not p) $ voteFor env $ candidateID msg
      let vote = Vote { granted = not p, term = t }
      sendChan (sendPort (msg :: Ballot)) vote
