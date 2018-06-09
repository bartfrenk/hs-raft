{-# LANGUAGE ConstraintKinds            #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase                 #-}

module Utils.Timer
  ( Ref,
    startTimer,
    resetTimer,
    cancelTimer
  ) where

import           Control.Distributed.Process
import           Control.Distributed.Process.Lifted.Class (MonadProcess, liftP)
import           Data.Binary                              (Binary)
import           Data.Typeable                            (Typeable)
import           GHC.Generics                             (Generic)
import           Utils.Duration

data TimerControl
  = Cancel
  | Reset
  deriving (Generic, Typeable)

instance Binary TimerControl

-- | Opaque identifier for timers.
newtype Ref =
  Ref ProcessId

type Serializable a = (Binary a, Typeable a)

-- | Starts a timer. The timer sends a message `msg` to process `pid` after `ms`
-- milliseconds.
startTimer :: (Serializable a, MonadProcess m) => Duration -> ProcessId -> a -> m Ref
startTimer ms pid msg = Ref `fmap` (liftP $ spawnLocal $ timer [ms] $ send pid msg)

-- | Resets the current duration until the next message to its original value.
resetTimer :: MonadProcess m => Ref -> m ()
resetTimer (Ref pid) = liftP $ send pid Reset

-- | Stops the timer. It will not send anymore messages.
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
