-- Copyright (c) 2014 Eric McCorkle.  All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
-- 3. Neither the name of the author nor the names of any contributors
--    may be used to endorse or promote products derived from this software
--    without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS ``AS IS''
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
-- TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
-- PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS
-- OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
-- SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
-- LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
-- USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
-- OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
{-# OPTIONS_GHC -Wall -Werror #-}
{-# LANGUAGE MultiParamTypeClasses, FlexibleContexts,
             FlexibleInstances, UndecidableInstances #-}

module Control.Monad.Symbols(
       MonadSymbols(..),
       SymbolsT,
       Symbols,
       runSymbolsT,
       runSymbols,
       mapSymbolsT
       ) where

import Control.Applicative
import Control.Monad.Cont
import Control.Monad.Error
import Control.Monad.Reader
import Control.Monad.State
import Control.Monad.Writer
import Control.Monad.Symbols.Class
import Data.Array
import Data.ByteString hiding (empty)
import Data.Symbol

newtype SymbolsT m a =
  SymbolsT { unpackSymbolsT :: (ReaderT (Array Symbol ByteString) m) a }

type Symbols a = SymbolsT IO a

-- | Execute the computation represented by a Symbols monad.
runSymbols :: Symbols a
           -- ^ The Symbols monad to execute.
           -> (Symbol, Symbol)
           -- ^ The low and high range of the symbols.
           -> [(Symbol, ByteString)]
           -- ^ The mapping of symbols.  The mapping to the lowest
           -- index is taken as the null symbol.
           -> IO a
runSymbols s = runSymbolsT s

-- | Execute the computation wrapped in a SymbolsT monad transformer.
runSymbolsT :: MonadIO m =>
               SymbolsT m a
            -- ^ The SymbolsT monad to execute.
            -> (Symbol, Symbol)
            -- ^ The low and high range of the symbols.  The lowest
            -- index is used as the index of the null symbol.
            -> [(Symbol, ByteString)]
            -- ^ The mapping of symbols to indexes.  The mapping to the
            -- lowest index is taken as the null symbol.
            -> m a
runSymbolsT s bound = runReaderT (unpackSymbolsT s) . array bound

mapSymbolsT :: (Monad m, Monad n) => (m a -> n b) -> SymbolsT m a -> SymbolsT n b
mapSymbolsT f = SymbolsT . mapReaderT f . unpackSymbolsT

nullSym' :: Monad m => (ReaderT (Array Symbol ByteString) m) Symbol
nullSym' = ask >>= return . fst . bounds

allNames' :: Monad m => (ReaderT (Array Symbol ByteString) m) [ByteString]
allNames' = ask >>= return . elems

name' :: Monad m => Symbol -> (ReaderT (Array Symbol ByteString) m) ByteString
name' sym = ask >>= return . (! sym)

allSyms' :: Monad m => (ReaderT (Array Symbol ByteString) m) [Symbol]
allSyms' = ask >>= return . indices

instance Monad m => Monad (SymbolsT m) where
  return = SymbolsT . return
  s >>= f = SymbolsT $ unpackSymbolsT s >>= unpackSymbolsT . f

instance Monad m => Applicative (SymbolsT m) where
  pure = return
  (<*>) = ap

instance (Monad m, Alternative m) => Alternative (SymbolsT m) where
  empty = lift empty
  s1 <|> s2 = SymbolsT ((unpackSymbolsT s1) <|> (unpackSymbolsT s2))

instance Functor (SymbolsT m) where
  fmap f = fmap f

instance Monad m => MonadSymbols (SymbolsT m) where
  nullSym = SymbolsT nullSym'
  allNames = SymbolsT allNames'
  allSyms = SymbolsT allSyms'
  name = SymbolsT . name'

instance MonadIO m => MonadIO (SymbolsT m) where
  liftIO = SymbolsT . liftIO

instance MonadTrans SymbolsT where
  lift = SymbolsT . lift

instance MonadCont m => MonadCont (SymbolsT m) where
  callCC f = SymbolsT (callCC (\c -> unpackSymbolsT (f (SymbolsT . c))))

instance (Error e, MonadError e m) => MonadError e (SymbolsT m) where
  throwError = lift . throwError
  m `catchError` h =
    SymbolsT (unpackSymbolsT m `catchError` (unpackSymbolsT . h))

instance MonadState s m => MonadState s (SymbolsT m) where
  get = lift get
  put = lift . put

instance MonadReader r m => MonadReader r (SymbolsT m) where
  ask = lift ask
  local f = mapSymbolsT (local f)

instance MonadWriter w m => MonadWriter w (SymbolsT m) where
  tell = lift . tell
  listen = mapSymbolsT listen
  pass = mapSymbolsT pass

instance MonadPlus m => MonadPlus (SymbolsT m) where
  mzero = lift mzero
  mplus s1 s2 = SymbolsT (mplus (unpackSymbolsT s1) (unpackSymbolsT s2))

instance MonadFix m => MonadFix (SymbolsT m) where
  mfix f = SymbolsT (mfix (unpackSymbolsT . f))