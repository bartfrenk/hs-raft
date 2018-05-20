{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DeriveGeneric   #-}

module Distributed.Timer where

import           Control.Distributed.Process
import           Control.Distributed.Process.Lifted.Class (MonadProcess, liftP)
import           Data.Binary                              (Binary)
import           Data.Typeable                            (Typeable)
import           GHC.Generics                             (Generic)

data TimerControl
  = Cancel
  | Reset
  deriving (Generic, Typeable)

instance Binary TimerControl

newtype TimerRef =
  TimerRef ProcessId

type Serializable a = (Binary a, Typeable a)

startTimer ::
     (Serializable a, MonadProcess m) => [Int] -> ProcessId -> a -> m TimerRef
startTimer mss pid msg =
  TimerRef `fmap` (liftP $ spawnLocal $ timer mss $ send pid msg)

resetTimer :: MonadProcess m => TimerRef -> m ()
resetTimer (TimerRef pid) = liftP $ send pid Reset

cancelTimer :: MonadProcess m => TimerRef -> m ()
cancelTimer (TimerRef pid) = liftP $ send pid Cancel

timer :: [Int] -> Process () -> Process ()
timer [] _ = pure ()
timer mss@(ms:rest) process = do
  cancel <- expectTimeout ms
  case cancel of
    Nothing -> timer rest process
    Just Cancel -> pure ()
    Just Reset -> timer mss process
