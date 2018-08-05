module Utils.Network
  ( getFreePort
  ) where

import           Control.Exception (bracket)
import           Network.Socket

getFreePort :: IO Integer
getFreePort =
  bracket getSocket close $ \s -> do
    bind s (SockAddrInet aNY_PORT iNADDR_ANY)
    toInteger <$> socketPort s
  where
    getSocket = socket AF_INET Stream defaultProtocol
