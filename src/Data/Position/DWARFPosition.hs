-- Copyright (c) 2016 Eric McCorkle.  All rights reserved.
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
{-# OPTIONS_GHC -funbox-strict-fields -Wall -Werror #-}
{-# LANGUAGE FlexibleInstances, MultiParamTypeClasses, FlexibleContexts #-}

module Data.Position.DWARFPosition(
       SimplePosition(..),
       DWARFPosition(..),
       basicPosition
       ) where

import Control.Monad.Positions
import Data.Hashable
import Data.Position.BasicPosition(BasicPosition)
import Text.Format hiding (line)
import Text.XML.Expat.Pickle
import Text.XML.Expat.Tree

import qualified Data.ByteString as Strict
import qualified Data.ByteString.UTF8 as Strict
import qualified Data.Position as Position
import qualified Data.Position.BasicPosition as BasicPosition

-- | A simple location in a source file.
data SimplePosition =
    -- | A span in a source file.
    Span {
      -- | The starting point.
      spanStart :: !Position.Point,
      -- | The starting point.
      spanEnd :: !Position.Point
    }
    -- | A specific line and column in a source file.
  | Point {
      -- | The position.
      pointPos :: !Position.Point
    }
  deriving (Ord, Eq)

-- | A position suitable for representation in the DWARF debugging
-- format.  DWARF positions have a nested structure.
data DWARFPosition defid tydefid =
    -- | A position within a definition.
    Def {
      -- | Identifier for the enclosing definition.
      defId :: !defid,
      -- | Position within the definition.
      defPos :: !SimplePosition
    }
    -- | A position within a type definition.
  | TypeDef {
      -- | The position of the type definition in which this position occurs.
      typeDefId :: !tydefid,
      -- | The position within the type definition.
      typeDefPos :: !SimplePosition
    }
    -- | A position within a basic block.
  | Block {
      -- | Position of the whole enclosing block.
      blockCtx :: !(DWARFPosition defid tydefid),
      -- | Position within the block.
      blockPos :: !SimplePosition
    }
    -- | A simple location in a file.
  | Simple {
      simplePos :: !SimplePosition
    }
    -- | A position representing a whole file.
  | File {
      -- | The name of the source file.
      fileName :: !Position.Filename
    }
    -- | A synthetic position, generated internally by a compiler.
  | Synthetic {
      -- | A description of the origin of this position.
      synthDesc :: !Strict.ByteString
    }
    -- | A command-line option.
  | CmdLine
  deriving (Ord, Eq)

-- | Extract the @BasicPosition@ representing the source point for
-- this @DWARFPosition@.
basicPosition :: DWARFPosition defid tydefid -> BasicPosition
basicPosition Def { defPos = Span { spanStart = start, spanEnd = end } } =
  BasicPosition.Span { BasicPosition.spanStart = start,
                       BasicPosition.spanEnd = end }
basicPosition Def { defPos = Point { pointPos = pos } } =
  BasicPosition.Point { BasicPosition.pointPos = pos }
basicPosition TypeDef { typeDefPos = Span { spanStart = start,
                                            spanEnd = end } } =
  BasicPosition.Span { BasicPosition.spanStart = start,
                       BasicPosition.spanEnd = end }
basicPosition TypeDef { typeDefPos = Point { pointPos = pos } } =
  BasicPosition.Point { BasicPosition.pointPos = pos }
basicPosition Block { blockPos = Span { spanStart = start, spanEnd = end } } =
  BasicPosition.Span { BasicPosition.spanStart = start,
                       BasicPosition.spanEnd = end }
basicPosition Block { blockPos = Point { pointPos = pos } } =
  BasicPosition.Point { BasicPosition.pointPos = pos }
basicPosition Simple { simplePos = Span { spanStart = start, spanEnd = end } } =
  BasicPosition.Span { BasicPosition.spanStart = start,
                       BasicPosition.spanEnd = end }
basicPosition Simple { simplePos = Point { pointPos = pos } } =
  BasicPosition.Point { BasicPosition.pointPos = pos }
basicPosition File { fileName = fname } =
  BasicPosition.File { BasicPosition.fileName = fname }
basicPosition Synthetic { synthDesc = desc } =
  BasicPosition.Synthetic { BasicPosition.synthDesc = desc }
basicPosition CmdLine = BasicPosition.CmdLine

instance Position.PositionInfo (DWARFPosition defid tydefid) where
  location Def { defPos = Span { spanStart = startpos, spanEnd = endpos } } =
    do
      Position.PointInfo { Position.pointFile = fname } <- pointInfo startpos
      return (Just (fname, Just (startpos, endpos)))
  location Def { defPos = Point { pointPos = pos } } =
    do
      Position.PointInfo { Position.pointFile = fname } <- pointInfo pos
      return (Just (fname, Just (pos, pos)))
  location TypeDef { typeDefPos = Span { spanStart = startpos,
                                         spanEnd = endpos } } =
    do
      Position.PointInfo { Position.pointFile = fname } <- pointInfo startpos
      return (Just (fname, Just (startpos, endpos)))
  location TypeDef { typeDefPos = Point { pointPos = pos } } =
    do
      Position.PointInfo { Position.pointFile = fname } <- pointInfo pos
      return (Just (fname, Just (pos, pos)))
  location Block { blockPos = Span { spanStart = startpos,
                                     spanEnd = endpos } } =
    do
      Position.PointInfo { Position.pointFile = fname } <- pointInfo startpos
      return (Just (fname, Just (startpos, endpos)))
  location Block { blockPos = Point { pointPos = pos } } =
    do
      Position.PointInfo { Position.pointFile = fname } <- pointInfo pos
      return (Just (fname, Just (pos, pos)))
  location Simple { simplePos = Span { spanStart = startpos,
                                       spanEnd = endpos } } =
    do
      Position.PointInfo { Position.pointFile = fname } <- pointInfo startpos
      return (Just (fname, Just (startpos, endpos)))
  location Simple { simplePos = Point { pointPos = pos } } =
    do
      Position.PointInfo { Position.pointFile = fname } <- pointInfo pos
      return (Just (fname, Just (pos, pos)))
  location File { fileName = fname } = return (Just (fname, Nothing))
  location _ = return Nothing

  description Synthetic { synthDesc = desc } = desc
  description CmdLine = Strict.fromString "from command line"
  description _ = Strict.empty

  children _ = Nothing

  showContext _ = True

instance (MonadPositions m) => FormatM m SimplePosition where
  formatM Span { spanStart = startpos, spanEnd = endpos } =
    do
      Position.PointInfo { Position.pointLine = startline,
                           Position.pointColumn = startcol,
                           Position.pointFile = fname } <- pointInfo startpos
      Position.PointInfo { Position.pointLine = endline,
                           Position.pointColumn = endcol } <- pointInfo endpos
      Position.FileInfo { Position.fileInfoName = fstr } <- fileInfo fname
      if startline == endline
        then return (hcat [bytestring fstr, colon, format startline, dot,
                           format startcol, char '-', format endcol])
        else return (hcat [bytestring fstr, colon,
                           format startline, dot, format startcol, char '-',
                           format endline, dot, format endcol])
  formatM Point { pointPos = pos } =
    do
      Position.PointInfo { Position.pointLine = line,
                           Position.pointColumn = col,
                           Position.pointFile = fname } <- pointInfo pos
      Position.FileInfo { Position.fileInfoName = fstr } <- fileInfo fname
      return (hcat [bytestring fstr, colon, format line, dot, format col])

instance (MonadPositions m, FormatM m defid, FormatM m tydefid) =>
         FormatM m (DWARFPosition defid tydefid) where
  formatM Def { defPos = pos, defId = ctx } =
    do
      posdoc <- formatM pos
      ctxdoc <- formatM ctx
      return $! posdoc <$$> nest 2 (string "in definition at" <+> ctxdoc)
  formatM Block { blockPos = pos, blockCtx = ctx } =
    do
      posdoc <- formatM pos
      ctxdoc <- formatM ctx
      return $! posdoc <$$> nest 2 (string "in block at" <+> ctxdoc)
  formatM TypeDef { typeDefPos = pos, typeDefId = ctx } =
    do
      posdoc <- formatM pos
      ctxdoc <- formatM ctx
      return $! posdoc <$$> nest 2 (string "in type defined at" <+> ctxdoc)
  formatM Simple { simplePos = pos } = formatM pos
  formatM File { fileName = fname } =
    do
      Position.FileInfo { Position.fileInfoName = fstr } <- fileInfo fname
      return (bytestring fstr)
  formatM CmdLine = return (string "command line")
  formatM Synthetic { synthDesc = desc } = return (bytestring desc)

instance Position.Position (DWARFPosition defid tydefid)
                           (DWARFPosition defid tydefid) where
  positionInfo pos = [pos]

instance Hashable SimplePosition where
  hashWithSalt s Span { spanStart = start, spanEnd = end } =
    s `hashWithSalt` (0 :: Word) `hashWithSalt` start `hashWithSalt` end
  hashWithSalt s Point { pointPos = pos } =
    s `hashWithSalt` (1 :: Word) `hashWithSalt` pos

instance (Hashable defid, Hashable tydefid) =>
         Hashable (DWARFPosition defid tydefid) where
  hashWithSalt s Def { defPos = pos, defId = ctx } =
    s `hashWithSalt` (0 :: Word) `hashWithSalt` pos `hashWithSalt` ctx
  hashWithSalt s TypeDef { typeDefPos = pos, typeDefId = ctx } =
    s `hashWithSalt` (1 :: Word) `hashWithSalt` pos `hashWithSalt` ctx
  hashWithSalt s Block { blockPos = pos, blockCtx = ctx } =
    s `hashWithSalt` (1 :: Word) `hashWithSalt` pos `hashWithSalt` ctx
  hashWithSalt s Simple { simplePos = pos } =
    s `hashWithSalt` (3 :: Word) `hashWithSalt` pos
  hashWithSalt s File { fileName = fname } =
    s `hashWithSalt` (4 :: Word) `hashWithSalt` fname
  hashWithSalt s Synthetic { synthDesc = desc } =
    s `hashWithSalt` (5 :: Word) `hashWithSalt` desc
  hashWithSalt s CmdLine = s `hashWithSalt` (4 :: Int)

spanPickler :: (GenericXMLString tag, Show tag,
                GenericXMLString text, Show text) =>
               PU [NodeG [] tag text] SimplePosition
spanPickler =
  let
    fwdfunc (start, end) = Span { spanStart = start, spanEnd = end }

    revfunc Span { spanStart = start, spanEnd = end } = (start, end)
    revfunc _ = error $! "Can't convert to Span"
  in
    xpWrap (fwdfunc, revfunc)
           (xpElemNodes (gxFromString "Span")
                        (xpPair (xpElemAttrs (gxFromString "start") xpickle)
                                (xpElemAttrs (gxFromString "end") xpickle)))

pointPickler :: (GenericXMLString tag, Show tag,
                 GenericXMLString text, Show text) =>
                PU [NodeG [] tag text] SimplePosition
pointPickler =
  let
    revfunc Point { pointPos = pos } = pos
    revfunc _ = error $! "Can't convert to Point"
  in
    xpWrap (Point, revfunc) (xpElemAttrs (gxFromString "Point") xpickle)

instance (GenericXMLString tag, Show tag, GenericXMLString text, Show text) =>
         XmlPickler [NodeG [] tag text] SimplePosition where
  xpickle =
    let
      picker Span {} = 0
      picker Point {} = 1
    in
      xpAlt picker [spanPickler, pointPickler ]

defPickler :: (GenericXMLString tag, Show tag,
               GenericXMLString text, Show text,
               XmlPickler [NodeG [] tag text] defid) =>
              PU [NodeG [] tag text] (DWARFPosition defid tydefid)
defPickler =
  let
    fwdfunc (pos, ctx) = Def { defPos = pos, defId = ctx }

    revfunc Def { defPos = pos, defId = ctx } = (pos, ctx)
    revfunc _ = error $! "Can't convert to Def"
  in
    xpWrap (fwdfunc, revfunc)
           (xpElemNodes (gxFromString "Def")
                        (xpPair (xpElemNodes (gxFromString "pos") xpickle)
                                (xpElemNodes (gxFromString "id") xpickle)))

typeDefPickler :: (GenericXMLString tag, Show tag,
                   GenericXMLString text, Show text,
                   XmlPickler [NodeG [] tag text] tydefid) =>
                  PU [NodeG [] tag text] (DWARFPosition funcid tydefid)
typeDefPickler =
  let
    fwdfunc (pos, ctx) = TypeDef { typeDefPos = pos, typeDefId = ctx }

    revfunc TypeDef { typeDefPos = pos, typeDefId = ctx } = (pos, ctx)
    revfunc _ = error $! "Can't convert to TypeDef"
  in
    xpWrap (fwdfunc, revfunc)
           (xpElemNodes (gxFromString "TypeDef")
                        (xpPair (xpElemNodes (gxFromString "pos") xpickle)
                                (xpElemNodes (gxFromString "id") xpickle)))

blockPickler :: (GenericXMLString tag, Show tag,
                 GenericXMLString text, Show text,
                 XmlPickler [NodeG [] tag text] funcid,
                 XmlPickler [NodeG [] tag text] tydefid) =>
                PU [NodeG [] tag text] (DWARFPosition funcid tydefid)
blockPickler =
  let
    fwdfunc (pos, ctx) = Block { blockPos = pos, blockCtx = ctx }

    revfunc Block { blockPos = pos, blockCtx = ctx } = (pos, ctx)
    revfunc _ = error $! "Can't convert to Block"
  in
    xpWrap (fwdfunc, revfunc)
           (xpElemNodes (gxFromString "Block")
                        (xpPair (xpElemNodes (gxFromString "pos") xpickle)
                                (xpElemNodes (gxFromString "ctx") xpickle)))

simplePickler :: (GenericXMLString tag, Show tag,
                  GenericXMLString text, Show text) =>
                 PU [NodeG [] tag text] (DWARFPosition funcid tydefid)
simplePickler =
  let
    revfunc Simple { simplePos = pos } = pos
    revfunc _ = error $! "Can't convert to Simple"
  in
    xpWrap (Simple, revfunc) (xpElemNodes (gxFromString "Simple") xpickle)

filePickler :: (GenericXMLString tag, Show tag,
                GenericXMLString text, Show text) =>
               PU [NodeG [] tag text] (DWARFPosition funcid tydefid)
filePickler =
  let
    revfunc File { fileName = fname } = fname
    revfunc _ = error $! "Can't convert to File"
  in
    xpWrap (File, revfunc) (xpElemAttrs (gxFromString "File") xpickle)

syntheticPickler :: (GenericXMLString tag, Show tag,
                     GenericXMLString text, Show text) =>
                    PU [NodeG [] tag text] (DWARFPosition funcid tydefid)
syntheticPickler =
  let
    revfunc Synthetic { synthDesc = desc } = gxFromByteString desc
    revfunc _ = error $! "Can't convert to Synthetic"
  in
    xpWrap (Synthetic . gxToByteString, revfunc)
           (xpElemNodes (gxFromString "Synthetic") (xpContent xpText))

cmdLinePickler :: (GenericXMLString tag, Show tag,
                   GenericXMLString text, Show text) =>
                  PU [NodeG [] tag text] (DWARFPosition funcid tydefid)
cmdLinePickler =
  let
    revfunc CmdLine = ()
    revfunc _ = error $! "Can't convert to CmdArg"
  in
    xpWrap (const CmdLine, revfunc)
           (xpElemNodes (gxFromString "CmdLine") xpUnit)

instance (GenericXMLString tag, Show tag, GenericXMLString text, Show text,
          XmlPickler [NodeG [] tag text] funcid,
          XmlPickler [NodeG [] tag text] tydefid) =>
         XmlPickler [NodeG [] tag text] (DWARFPosition funcid tydefid) where
  xpickle =
    let
      picker Def {} = 0
      picker TypeDef {} = 1
      picker Block {} = 2
      picker Simple {} = 3
      picker File {} = 4
      picker Synthetic {} = 5
      picker CmdLine {} = 6
    in
      xpAlt picker [defPickler, typeDefPickler, blockPickler, simplePickler,
                    filePickler, syntheticPickler, cmdLinePickler]
