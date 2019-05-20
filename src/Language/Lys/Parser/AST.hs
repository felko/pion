{-# LANGUAGE
    TemplateHaskell
  #-}

module Language.Lys.Parser.AST where

import Language.Lys.Types.Context
import Language.Lys.Types

import Control.Lens hiding (Context(..))

data Process
    = NilP
    | ParP Process Process
    | NewP String (Maybe Type) Process
    | OutputP Name Name Process
    | InputP Name String Process
    | ReplicateP Name String Process
    | InjectP Name String Name Process
    | MatchP Name [Branch Process]
    | CallP String [Name]
    | SourceP String String Process
    | ContractP String String Process Process
    deriving (Eq, Show)
makePrisms ''Process

data Constraint
    = NoneC
    deriving (Eq, Show)

data TypeParam
    = ParamTP { _tpName :: String }
    | ConstrTP { _tpName :: String, _tpConstr :: Constraint }
    deriving (Eq, Show)
makeLenses ''TypeParam
makePrisms ''TypeParam

data NameParam
    = InferredNP { _npName :: String }
    | AnnotatedNP { _npName :: String, _npType :: Type }
    deriving (Eq, Show)
makeLenses ''NameParam
makePrisms ''NameParam

type ModuleName = [String]

data Declaration
    = TypeD String [TypeParam] Type
    | ProcessD String [TypeParam] [NameParam] Process
    deriving (Eq, Show)

data Export
    = TypeE String
    | ProcessE String
    | ModuleE ModuleName
    deriving (Eq, Show)

data Import
    = ImportI ModuleName
    deriving (Eq, Show)

data Program = Program
    { _moduleName    :: ModuleName
    , _moduleExports :: [Export]
    , _moduleImports :: [Import]
    , _declarations  :: [Declaration] }
    deriving Show
makeLenses ''Program
