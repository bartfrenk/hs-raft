{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Utils where

import           Control.Arrow       (first)
import           Control.Concurrent
import           Control.Monad.Trans (MonadIO)
import           Control.Monad.Trans (liftIO)
import           System.Random

newtype Duration =
  Duration Int
  deriving (Eq, Ord, Show)

instance Random Duration where
  randomR (Duration lo, Duration hi) g = first Duration $ randomR (lo, hi) g
  random g = first Duration $ random g

microseconds :: Int -> Duration
microseconds = Duration

milliseconds :: Int -> Duration
milliseconds = Duration . (* 1000)

delay :: MonadIO m => Duration -> m ()
delay (Duration us) = liftIO $ threadDelay us

data RandomVar a =
  Uniform a a

class MonadRandom a m where
  sample :: RandomVar a -> m a

instance Random a => (MonadRandom a) IO where
  sample (Uniform lo hi) = randomRIO (lo, hi)
