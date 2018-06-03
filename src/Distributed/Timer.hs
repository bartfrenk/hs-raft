{-# LANGUAGE ConstraintKinds            #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase                 #-}

module Distributed.Timer where

import           Control.Distributed.Process
import           Control.Distributed.Process.Lifted.Class (MonadProcess, liftP)
import           Data.Binary                              (Binary)
import           Data.Typeable                            (Typeable)
import           GHC.Generics                             (Generic)
import           Utils

data TimerControl
  = Cancel
  | Reset
  deriving (Generic, Typeable)

instance Binary TimerControl

newtype Ref =
  Ref ProcessId

type Serializable a = (Binary a, Typeable a)

startTimer :: (Serializable a, MonadProcess m) => Duration -> ProcessId -> a -> m Ref
startTimer ms pid msg = Ref `fmap` (liftP $ spawnLocal $ timer [ms] $ send pid msg)

resetTimer :: MonadProcess m => Ref -> m ()
resetTimer (Ref pid) = liftP $ send pid Reset

cancelTimer :: MonadProcess m => Ref -> m ()
cancelTimer (Ref pid) = liftP $ send pid Cancel

timer :: [Duration] -> Process () -> Process ()
timer [] _ = pure ()
timer mss@(Duration us:rest) process = do
  expectTimeout us >>= \case
    Nothing -> do
      process
      timer rest process
    Just Cancel -> pure ()
    Just Reset -> timer mss process
