{-# LANGUAGE
  TemplateHaskell
  #-}
module LLVM.General.Internal.FFI.Cleanup where

import Language.Haskell.TH
import Control.Monad
import Data.Sequence as Seq
import Data.Foldable (toList)

import Data.Function

import LLVM.General.Internal.FFI.LLVMCTypes
import Data.Word
import Data.Int
import Foreign.C
import Foreign.Ptr

import qualified LLVM.General.AST.IntegerPredicate as A (IntegerPredicate) 
import qualified LLVM.General.AST.FloatingPointPredicate as A (FloatingPointPredicate) 

foreignDecl :: String -> String -> [TypeQ] -> TypeQ -> DecsQ
foreignDecl cName hName argTypeQs returnTypeQ = do
  let foreignDecl' hName argTypeQs = 
        forImpD cCall unsafe cName (mkName hName) 
                  (foldr (\a b -> appT (appT arrowT a) b) (appT (conT ''IO) returnTypeQ) argTypeQs)
      splitTuples :: [Type] -> Q ([Type], [Pat], [Exp])
      splitTuples ts = do
        let f :: Type -> Q (Seq Type, Pat, Seq Exp)
            f x@(AppT _ _) = maybe (d x) (\q -> q >>= \(ts, ps, es) -> return (ts, TupP (toList ps), es)) (g 0 x)
            f x = d x
            g :: Int -> Type -> Maybe (Q (Seq Type, Seq Pat, Seq Exp))
            g n (TupleT m) | m == n = return (return (Seq.empty, Seq.empty, Seq.empty))
            g n (AppT a b) = do
              k <- g (n+1) a
              return $ do
                (ts, ps, es) <- k
                (ts', p', es') <- f b
                return (ts >< ts', ps |> p', es >< es')
            g _ _ = Nothing
            d :: Type -> Q (Seq Type, Pat, Seq Exp)
            d x = do
              n <- newName "v"
              return (Seq.singleton x, VarP n, Seq.singleton (VarE n))
            seqsToList :: [Seq a] -> [a]
            seqsToList = toList . foldr (><) Seq.empty
                
        (tss, ps, ess) <- liftM unzip3 . mapM f $ ts
        return (seqsToList tss, ps, seqsToList ess)

                                
  argTypes <- sequence argTypeQs
  (ts, ps, es) <- splitTuples argTypes
  let phName = hName ++ "'"
  sequence [
    foreignDecl' phName (map return ts),
    funD (mkName hName) [
     clause (map return ps) (normalB (foldl appE (varE (mkName phName)) (map return es))) []
    ]
   ]

typeMappingU :: (Type -> TypeQ) -> Type -> TypeQ
typeMappingU typeMapping t = case t of
  ConT h | h == ''Bool -> [t| LLVMBool |]
         | h == ''Int32 -> [t| CInt |]
         | h == ''Word32 -> [t| CUInt |]
         | h == ''String -> [t| CString |]
         | h == ''A.FloatingPointPredicate -> [t| FCmpPredicate |]
         | h == ''A.IntegerPredicate -> [t| ICmpPredicate |]
  AppT ListT x -> foldl1 appT [tupleT 2, [t| CUInt |], appT [t| Ptr |] (typeMapping x)]

typeMapping :: Type -> TypeQ
typeMapping = fix typeMappingU
