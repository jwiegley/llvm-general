module LLVM.General.Test.DataLayout where

import Test.Framework
import Test.Framework.Providers.HUnit
import Test.HUnit

import LLVM.General.Test.Support

import qualified Data.Set as Set

import LLVM.General.Context
import LLVM.General.Module
import LLVM.General.AST
import LLVM.General.AST.DataLayout
import qualified LLVM.General.AST.Global as G

tests = testGroup "DataLayout" [
  testCase name $ strCheck (Module "<string>" mdl Nothing []) ("; ModuleID = '<string>'\n" ++ sdl)
  | (name, mdl, sdl) <- [
   ("none",Nothing, "")
  ] ++ [
   (name, Just mdl, "target datalayout = \"" ++ sdl ++ "\"\n")
   | (name, mdl, sdl) <- [
    ("little-endian", defaultDataLayout { endianness = Just LittleEndian }, "e"),
    ("big-endian", defaultDataLayout { endianness = Just BigEndian }, "E"),
    ("native", defaultDataLayout { nativeSizes = Just (Set.fromList [8,32]) }, "n8:32")
   ]
  ]
 ]
