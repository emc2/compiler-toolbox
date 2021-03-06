-- Copyright (c) 2014 Eric McCorkle.  All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
--
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
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

module Control.Monad.Frontend(
       MonadCommentBuffer(..),
       MonadGenpos(..),
       MonadGensym(..),
       MonadPositions(..),
       MonadKeywords(..),
       MonadMessages(..),
       FrontendT,
       Frontend,
       FrontendNoCommentsT,
       FrontendNoComments,
       FrontendNoBufferT,
       FrontendNoBuffer,
       FrontendNoCommentsNoBufferT,
       FrontendNoCommentsNoBuffer,
       runFrontendT,
       runFrontend,
       runFrontendNoCommentsT,
       runFrontendNoComments,
       runFrontendNoBufferT,
       runFrontendNoBuffer,
       runFrontendNoCommentsNoBufferT,
       runFrontendNoCommentsNoBuffer
       ) where

import Control.Monad.CommentBuffer
import Control.Monad.Genpos
import Control.Monad.Gensym
import Control.Monad.Keywords
import Control.Monad.Messages
import Control.Monad.SourceBuffer
import Control.Monad.SkipComments
import Control.Monad.Trans
import Data.ByteString

-- | Frontend monad transformer
type FrontendT pos tok m =
  (KeywordsT pos tok (CommentBufferT (SourceBufferT (GenposT (GensymT m)))))

-- | Frontend monad
type Frontend pos tok = FrontendT pos tok IO

-- | Frontend monad transformer without comment buffering
type FrontendNoCommentsT pos tok m a =
  (KeywordsT pos tok (SkipCommentsT (SourceBufferT (GenposT (GensymT m))))) a

-- | Frontend monad without comment buffering
type FrontendNoComments pos tok a = FrontendNoCommentsT pos tok IO a

-- | Frontend monad transformer without source buffering
type FrontendNoBufferT pos tok m =
  (KeywordsT pos tok (CommentBufferT (GenposT (GensymT m))))

-- | Frontend monad without source buffering
type FrontendNoBuffer pos tok = FrontendNoBufferT pos tok IO

-- | Frontend monad transformer without source buffering
type FrontendNoCommentsNoBufferT pos tok m =
  (KeywordsT pos tok (SkipCommentsT (GenposT (GensymT m))))

-- | Frontend monad without source buffering
type FrontendNoCommentsNoBuffer pos tok = FrontendNoCommentsNoBufferT pos tok IO

runFrontendT :: MonadIO m => FrontendT pos tok m a
          -> [(ByteString, pos -> tok)]
          -> m a
runFrontendT lexer keywords =
  let
    commentbuffer = runKeywordsT lexer keywords
    srcbuf = runCommentBufferT commentbuffer
    genpos = runSourceBufferT srcbuf
    gensym = startGenposT genpos
  in
    startGensymT gensym

runFrontend :: Frontend pos tok a
            -> [(ByteString, pos -> tok)]
            -> IO a
runFrontend = runFrontendT

runFrontendNoCommentsT :: MonadIO m => FrontendNoCommentsT pos tok m a
                       -> [(ByteString, pos -> tok)]
                       -> m a
runFrontendNoCommentsT lexer keywords =
  let
    commentbuffer = runKeywordsT lexer keywords
    srcbuf = runSkipCommentsT commentbuffer
    genpos = runSourceBufferT srcbuf
    gensym  = startGenposT genpos
  in
    startGensymT gensym

runFrontendNoComments :: FrontendNoComments pos tok a
                      -> [(ByteString, pos -> tok)]
                      -> IO a
runFrontendNoComments = runFrontendNoCommentsT

runFrontendNoBufferT :: MonadIO m => FrontendNoBufferT pos tok m a
                     -> [(ByteString, pos -> tok)]
                     -> m a
runFrontendNoBufferT lexer keywords =
  let
    commentbuffer = runKeywordsT lexer keywords
    genpos = runCommentBufferT commentbuffer
    gensym  = startGenposT genpos
  in
    startGensymT gensym

runFrontendNoBuffer :: FrontendNoBuffer pos tok a
                    -> [(ByteString, pos -> tok)]
                    -> IO a
runFrontendNoBuffer = runFrontendNoBufferT

runFrontendNoCommentsNoBufferT :: MonadIO m => FrontendNoBufferT pos tok m a
                               -> [(ByteString, pos -> tok)]
                               -> m a
runFrontendNoCommentsNoBufferT lexer keywords =
  let
    commentbuffer = runKeywordsT lexer keywords
    genpos = runCommentBufferT commentbuffer
    gensym  = startGenposT genpos
  in
    startGensymT gensym

runFrontendNoCommentsNoBuffer :: FrontendNoBuffer pos tok a
                              -> [(ByteString, pos -> tok)]
                              -> IO a
runFrontendNoCommentsNoBuffer = runFrontendNoBufferT
