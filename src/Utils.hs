{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Utils where

import           Control.Concurrent
import           Control.Monad.Trans (MonadIO)
import           Control.Monad.Trans (liftIO)
import           System.Random

type Unit = Int -> Int

delay :: MonadIO m => Int -> Unit -> m ()
delay us unit = liftIO $ threadDelay (unit us)

seconds :: Unit
seconds = (* 1000000)

milliseconds :: Unit
milliseconds = (* 1000)

data RandomVar a =
  Uniform a
          a

class MonadRandom a m where
  sample :: RandomVar a -> m a

instance Random a => (MonadRandom a) IO where
  sample (Uniform lo hi) = randomRIO (lo, hi)
