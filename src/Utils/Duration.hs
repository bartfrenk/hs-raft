{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Utils.Duration where

import           Control.Arrow       (first)
import           Control.Concurrent
import           Control.Monad.Trans (MonadIO)
import           Control.Monad.Trans (liftIO)
import           System.Random

newtype Duration =
  Duration Int
  deriving (Eq, Ord)

instance Show Duration where
  show (Duration us) = show us ++ " us"

instance Random Duration where
  randomR (Duration lo, Duration hi) g = first Duration $ randomR (lo, hi) g
  random g = first Duration $ random g

seconds :: Int -> Duration
seconds = Duration . (* 1000000)

microseconds :: Int -> Duration
microseconds = Duration

milliseconds :: Int -> Duration
milliseconds = Duration . (* 1000)

delay :: MonadIO m => Duration -> m ()
delay (Duration us) = liftIO $ threadDelay us
