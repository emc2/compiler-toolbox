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

-- | Defines a class of monads that have access to preserved comments.
module Control.Monad.Comments.Class(
       MonadComments(..)
       ) where

import Control.Monad.Cont
import Control.Monad.Except
import Control.Monad.List
import Control.Monad.Reader
import Control.Monad.State
import Control.Monad.Trans.Journal
import Control.Monad.Writer
import Data.ByteString
import Data.Position.Point

-- | Class of monads that store comments referenced by a 'Point'.
class Monad m => MonadComments m where
  -- | Get all comments preceeding a given 'Point'.
  preceedingComments :: Point -> m [ByteString]

instance MonadComments m => MonadComments (ContT r m) where
  preceedingComments = lift . preceedingComments

instance (MonadComments m) => MonadComments (ExceptT e m) where
  preceedingComments = lift . preceedingComments

instance (MonadComments m) => MonadComments (JournalT e m) where
  preceedingComments = lift . preceedingComments

instance MonadComments m => MonadComments (ListT m) where
  preceedingComments = lift . preceedingComments

instance MonadComments m => MonadComments (ReaderT s m) where
  preceedingComments = lift . preceedingComments

instance MonadComments m => MonadComments (StateT s m) where
  preceedingComments = lift . preceedingComments

instance (Monoid w, MonadComments m) => MonadComments (WriterT w m) where
  preceedingComments = lift . preceedingComments
