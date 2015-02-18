{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE RecordWildCards #-}

module Network.Wai.Handler.Warp.HTTP2.Worker where

import Control.Concurrent
import Control.Concurrent.STM
import Control.Exception as E
import Control.Monad (void, forever)
import Data.Typeable
import Network.HTTP2
import Network.Wai
import Network.Wai.Handler.Warp.HTTP2.Response
import Network.Wai.Handler.Warp.HTTP2.Types
import Network.Wai.Handler.Warp.IORef

data Break = Break deriving (Show, Typeable)

instance Exception Break

-- Confirmed that this logic does not leak space.
-- fixme: tickle activity
worker :: Context -> Application -> EnqRsp -> IO ()
worker Context{..} app enQResponse = go `E.catch` gonext
  where
    go = forever $ do
        Input Stream{..} req <- atomically $ readTQueue inputQ
        let stid = fromStreamIdentifier streamNumber
        tid <- myThreadId
        E.bracket (writeIORef streamTimeoutAction $ E.throwTo tid Break)
                  (\_ -> writeIORef streamTimeoutAction $ return ())
                  (\_ -> void $ app req $ enQResponse stid)
    gonext Break = go `E.catch` gonext

