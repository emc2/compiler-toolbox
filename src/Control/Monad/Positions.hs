-- Copyright (c) 2016 Eric McCorkle.  All rights reserved.
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

module Control.Monad.Positions(
       MonadPositions(..),
       PositionsT,
       Positions,
       runPositionsT,
       runPositions,
       mapPositionsT
       ) where

import Control.Applicative
import Control.Monad.Artifacts.Class
import Control.Monad.CommentBuffer.Class
import Control.Monad.Comments.Class
import Control.Monad.Cont
import Control.Monad.Except
import Control.Monad.Gensym.Class
import Control.Monad.GraphBuilder.Class
import Control.Monad.Journal
import Control.Monad.Keywords.Class
import Control.Monad.Loader.Class
import Control.Monad.Messages.Class
import Control.Monad.Positions.Class
import Control.Monad.Reader
import Control.Monad.ScopeBuilder.Class
import Control.Monad.SourceFiles.Class
import Control.Monad.SourceBuffer.Class
import Control.Monad.State
import Control.Monad.Symbols.Class
import Control.Monad.Writer
import Data.Array
import Data.Position.Filename
import Data.Position.Point

data Info =
  Info {
    pointInfoArray :: !(Array Point PointInfo),
    fileInfoArray :: !(Array Filename FileInfo)
  }

newtype PositionsT m a = PositionsT { unpackPositionsT :: (ReaderT Info m) a }

type Positions a = PositionsT IO a

-- | Execute the computation represented by a Positions monad.
runPositions :: Positions a
             -- ^ The Positions monad to execute.
             -> (Point, Point)
             -- ^ The low and high range of the symbols.
             -> [(Point, PointInfo)]
             -- ^ The mapping of symbols.  The mapping to the lowest
             -- index is taken as the null symbol.
             -> (Filename, Filename)
             -- ^ The low and high range of the symbols.
             -> [(Filename, FileInfo)]
             -- ^ The mapping of symbols.  The mapping to the lowest
             -- index is taken as the null symbol.
             -> IO a
runPositions = runPositionsT

-- | Execute the computation wrapped in a PositionsT monad transformer.
runPositionsT :: Monad m =>
                 PositionsT m a
                 -- ^ The PositionsT monad to execute.
                 -> (Point, Point)
                 -- ^ The low and high range of the symbols.  The lowest
                 -- index is used as the index of the null symbol.
                 -> [(Point, PointInfo)]
                 -- ^ The mapping of symbols to indexes.  The mapping to the
                 -- lowest index is taken as the null symbol.
                 -> (Filename, Filename)
                 -- ^ The low and high range of the symbols.
                 -> [(Filename, FileInfo)]
                 -- ^ The mapping of symbols.  The mapping to the lowest
                 -- index is taken as the null symbol.
                 -> m a
runPositionsT s posbounds positions filebounds file =
  runReaderT (unpackPositionsT s)
             Info { pointInfoArray = array posbounds positions,
                    fileInfoArray = array filebounds file }

mapPositionsT :: (Monad m, Monad n) =>
                 (m a -> n b) -> PositionsT m a -> PositionsT n b
mapPositionsT f = PositionsT . mapReaderT f . unpackPositionsT

pointInfo' :: Monad m => Point -> (ReaderT Info m) PointInfo
pointInfo' pos = liftM ((! pos) . pointInfoArray) ask

fileInfo' :: Monad m => Filename -> (ReaderT Info m) FileInfo
fileInfo' pos = liftM ((! pos) . fileInfoArray) ask

instance Monad m => Monad (PositionsT m) where
  return = PositionsT . return
  s >>= f = PositionsT $ unpackPositionsT s >>= unpackPositionsT . f

instance Monad m => Applicative (PositionsT m) where
  pure = return
  (<*>) = ap

instance (Monad m, Alternative m) => Alternative (PositionsT m) where
  empty = lift empty
  s1 <|> s2 = PositionsT (unpackPositionsT s1 <|> unpackPositionsT s2)

instance Functor (PositionsT m) where
  fmap = fmap

instance Monad m => MonadPositions (PositionsT m) where
  pointInfo = PositionsT . pointInfo'
  fileInfo = PositionsT . fileInfo'

instance MonadIO m => MonadIO (PositionsT m) where
  liftIO = PositionsT . liftIO

instance MonadTrans PositionsT where
  lift = PositionsT . lift

instance MonadArtifacts path m => MonadArtifacts path (PositionsT m) where
  artifact path = lift . artifact path
  artifactBytestring path = lift . artifactBytestring path
  artifactLazyBytestring path = lift . artifactLazyBytestring path

instance MonadCommentBuffer m => MonadCommentBuffer (PositionsT m) where
  startComment = lift startComment
  appendComment = lift . appendComment
  finishComment = lift finishComment
  addComment = lift . addComment
  saveCommentsAsPreceeding = lift . saveCommentsAsPreceeding
  clearComments = lift clearComments

instance MonadComments m => MonadComments (PositionsT m) where
  preceedingComments = lift . preceedingComments

instance MonadCont m => MonadCont (PositionsT m) where
  callCC f = PositionsT (callCC (\c -> unpackPositionsT (f (PositionsT . c))))

instance (MonadError e m) => MonadError e (PositionsT m) where
  throwError = lift . throwError
  m `catchError` h =
    PositionsT (unpackPositionsT m `catchError` (unpackPositionsT . h))

instance MonadEdgeBuilder nodety m =>
         MonadEdgeBuilder nodety (PositionsT m) where
  addEdge src dst = lift . addEdge src dst

instance MonadGensym m => MonadGensym (PositionsT m) where
  symbol = lift . symbol
  unique = lift . unique

instance (Monoid w, MonadJournal w m) => MonadJournal w (PositionsT m) where
  journal = lift . journal
  history = lift history
  clear = lift clear

instance MonadKeywords p t m => MonadKeywords p t (PositionsT m) where
  mkKeyword p = lift . mkKeyword p

instance MonadLoader path info m => MonadLoader path info (PositionsT m) where
  load = lift . load

instance MonadMessages msg m => MonadMessages msg (PositionsT m) where
  message = lift . message

instance MonadNodeBuilder nodety m =>
         MonadNodeBuilder nodety (PositionsT m) where
  addNode = lift . addNode

instance MonadScopeStack m => MonadScopeStack (PositionsT m) where
  enterScope = lift . enterScope
  finishScope = lift finishScope

instance MonadScopeBuilder tmpscope m =>
         MonadScopeBuilder tmpscope (PositionsT m) where
  getScope = lift getScope
  setScope = lift . setScope

instance MonadSourceFiles m => MonadSourceFiles (PositionsT m) where
  sourceFile = lift . sourceFile

instance MonadSourceBuffer m => MonadSourceBuffer (PositionsT m) where
  linebreak = lift . linebreak
  startFile fname = lift . startFile fname
  finishFile = lift finishFile

instance MonadState s m => MonadState s (PositionsT m) where
  get = lift get
  put = lift . put

instance MonadSymbols m => MonadSymbols (PositionsT m) where
  nullSym = lift nullSym
  allNames = lift allNames
  allSyms = lift allSyms
  name = lift . name

instance MonadReader r m => MonadReader r (PositionsT m) where
  ask = lift ask
  local f = mapPositionsT (local f)

instance MonadWriter w m => MonadWriter w (PositionsT m) where
  tell = lift . tell
  listen = mapPositionsT listen
  pass = mapPositionsT pass

instance MonadPlus m => MonadPlus (PositionsT m) where
  mzero = lift mzero
  mplus s1 s2 = PositionsT (mplus (unpackPositionsT s1) (unpackPositionsT s2))

instance MonadFix m => MonadFix (PositionsT m) where
  mfix f = PositionsT (mfix (unpackPositionsT . f))
