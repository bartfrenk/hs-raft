{-# LANGUAGE FlexibleContexts #-}

module Utils where

import           Control.Concurrent
import           Control.Monad.Trans (MonadIO)
import           Control.Monad.Trans (liftIO)

type Unit = Int -> Int

delay :: MonadIO m => Int -> Unit -> m ()
delay us unit = liftIO $ threadDelay (unit us)

seconds :: Unit
seconds = (* 1000000)

milliseconds :: Unit
milliseconds = (* 1000)
