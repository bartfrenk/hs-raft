{-# LANGUAGE ConstraintKinds            #-}
{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase                 #-}

module Utils.Timer
  ( Ref
  , startTimer
  , startTicker
  , resetTimer
  , cancelTimer
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

startTicker :: (Serializable a, MonadProcess m) => Duration -> ProcessId -> a -> m Ref
startTicker dt pid msg =
  let dts = repeat dt
  in Ref `fmap` (liftP $ spawnLocal $ timer dts $ send pid msg)

-- | Starts a timer. The timer sends a message `msg` to process `pid` after `dt`.
startTimer :: (Serializable a, MonadProcess m) => Duration -> ProcessId -> a -> m Ref
startTimer dt pid msg = Ref `fmap` (liftP $ spawnLocal $ timer [dt] $ send pid msg)

-- | Resets the current duration until the next message to its original value.
resetTimer :: MonadProcess m => Ref -> m ()
resetTimer (Ref pid) = liftP $ send pid Reset

-- | Stops the timer. It will not send anymore messages.
cancelTimer :: MonadProcess m => Ref -> m ()
cancelTimer (Ref pid) = liftP $ send pid Cancel

timer :: [Duration] -> Process () -> Process ()
timer [] _ = pure ()
timer dts@(Duration us:rest) process = do
  expectTimeout us >>= \case
    Nothing -> do
      process
      timer rest process
    Just Cancel -> pure ()
    Just Reset -> timer dts process
