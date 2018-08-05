{-# OPTIONS_GHC -fno-warn-orphans #-}
module Orphans where

import           Control.Distributed.Process.Internal.Types
import           System.Console.Haskeline

-- | Required for Haskeline. Too much work to wrap in a newtype.
instance MonadException Process where
  controlIO f =
    Process $
    controlIO $ \(RunIO run) ->
      let run' = RunIO $ (fmap Process) . run . unProcess
      in fmap unProcess $ f run'
