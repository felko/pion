{-# LANGUAGE TypeApplications #-}

-- Concrete syntax.

module Language.Pion.Syntax.Concrete
  ( Type (..),
    Context,
    Sequent (..),
    Literal (..),
    Expression (..),
    Pattern (..),
    Action (..),
    Process (..),
    TypeDeclaration (..),
    ProcessDeclaration (..),
    FunctionDeclaration (..),
    Declaration (..),
    Module (..),
    module Language.Pion.Name,
    module Language.Pion.Syntax.Common,
    module Language.Pion.Type,
  )
where

import Language.Pion.Name
import Language.Pion.Pretty
import Language.Pion.SourceSpan
import Language.Pion.Syntax.Common
import Language.Pion.Type

-- | Concrete syntax tree of types.
data Type
  = ConnT ConnectiveType (Conjunction Type)
  | UnitT ConnectiveType
  | ExpT ModalityType (Located Type)
  | VarT Identifier
  deriving (Eq, Show)

instance Pretty Type where
  pretty = \case
    ConnT connective types ->
      prettySyntaxNode
        "Conn"
        [ ("connective", pretty (show @Text connective)),
          ("types", pretty types)
        ]
    UnitT connective ->
      prettyLabelled "Unit" $ pretty (show @Text connective)
    ExpT modality type' ->
      prettySyntaxNode
        "Exp"
        [ ("modality", pretty (show @Text modality)),
          ("type", pretty type')
        ]
    VarT identifier ->
      prettyLabelled "Var" $ pretty identifier

-- | A typing context.
type Context = Branches Name Type

-- | Process types.
data Sequent = Sequent
  { sequentAntecedents :: Context,
    sequentSuccedents :: Context
  }
  deriving (Eq, Show)

instance Pretty Sequent where
  pretty Sequent {..} =
    prettySyntaxNode
      "Sequent"
      [ ("antecedents", pretty sequentAntecedents),
        ("succedents", pretty sequentSuccedents)
      ]

data Pattern
  = -- | Identity
    VarP Name
  | -- | Elimination of "tensor"
    SplitP (Conjunction Pattern)
  | -- | Elimination of "with"
    SelectP (Located Name) (Located Pattern)
  | -- | Dereliction of "of course"
    ExtractP (Located Pattern)
  | -- | Dereliction of "why not"
    UnwrapP (Located Pattern)
  | -- | Contraction or weakening of "of course"
    CopyP [Located Pattern]
  deriving (Eq, Ord, Show)

instance Pretty Pattern where
  pretty = \case
    VarP name ->
      prettyLabelled "Var" $ pretty name
    SplitP elements ->
      prettyLabelled "Split" $ pretty elements
    SelectP label pattern' ->
      prettySyntaxNode
        "Select"
        [ ("label", pretty label),
          ("pattern", pretty pattern')
        ]
    ExtractP pattern' ->
      prettyLabelled "Extract" $ pretty pattern'
    UnwrapP pattern' ->
      prettyLabelled "Unwrap" $ pretty pattern'
    CopyP copies ->
      prettyLabelled "Copy" $ prettySyntaxList (pretty <$> copies)

data Expression
  = -- | Identity
    VarE Name
  | -- | Introduction of "lollipop"
    AbsE (Located Name) (Located Expression)
  | -- | Elimination of "lollipop"
    AppE (Located Expression) (Located Expression)
  | -- | A literal value
    LitE Literal
  | -- | Introduction of "tensor"
    TupleE (Conjunction Expression)
  | -- | Introduction of "with"
    AltE (Conjunction Expression)
  | -- | Elimination of "plus"
    MatchE (Located Expression) (Branches Pattern Expression)
  | -- | Let-binding
    LetE (Branches Pattern Expression) (Located Expression)
  deriving (Eq, Ord, Show)

instance Pretty Expression where
  pretty = \case
    AppE callee argument ->
      prettySyntaxNode
        "App"
        [ ("callee", pretty callee),
          ("argument", pretty argument)
        ]
    VarE name ->
      prettySyntaxNode
        "Var"
        [ ("name", pretty name)
        ]
    AbsE variable body ->
      prettySyntaxNode
        "Abs"
        [ ("variable", pretty variable),
          ("body", pretty body)
        ]
    LitE lit ->
      let litType = case lit of
            IntL {} -> "int"
            FloatL {} -> "float"
            CharL {} -> "char"
            StringL {} -> "string"
       in prettySyntaxNode
            "Lit"
            [ ("type", litType),
              ("value", pretty lit)
            ]
    TupleE fields ->
      prettyLabelled "Tuple" (pretty fields)
    AltE cases ->
      prettyLabelled "Alt" (pretty cases)
    MatchE value cases ->
      prettySyntaxNode
        "Match"
        [ ("matched", pretty value),
          ("cases", pretty cases)
        ]
    LetE bindings body ->
      prettySyntaxNode
        "Let"
        [ ("bindings", pretty bindings),
          ("body", pretty body)
        ]

data Action
  = -- | p → x; P
    InputA (Located Name) (Located Pattern)
  | -- | P; x ← e
    OutputA (Located Name) (Located Expression)
  | -- | run p { x ← a, y → b }
    RunA (Located Identifier) PortMap
  | -- | join z { x : P | y : Q }
    JoinA (Located Name) (Branches Name Process)
  | -- | fork z { x : P | y : Q }
    ForkA (Located Name) (Branches Name Process)
  | -- | alt z { x : P | y : Q }
    AltA (Located Name) (Branches Label Process)
  | -- | match z { x : P | y : Q }
    MatchA (Located Name) (Branches Label Process)
  deriving (Eq, Ord, Show)

instance Pretty Action where
  pretty = \case
    InputA name pat ->
      prettySyntaxNode
        "Input"
        [ ("name", pretty name),
          ("pattern", pretty pat)
        ]
    OutputA name expr ->
      prettySyntaxNode
        "Output"
        [ ("name", pretty name),
          ("expression", pretty expr)
        ]
    RunA ident ports ->
      prettySyntaxNode
        "Run"
        [ ("ident", pretty ident),
          ("ports", pretty ports)
        ]
    JoinA name procs ->
      prettySyntaxNode
        "Join"
        [ ("name", pretty name),
          ("processes", pretty procs)
        ]
    ForkA name procs ->
      prettySyntaxNode
        "Fork"
        [ ("name", pretty name),
          ("processes", pretty procs)
        ]
    AltA name procs ->
      prettySyntaxNode
        "Alt"
        [ ("name", pretty name),
          ("processes", pretty procs)
        ]
    MatchA name procs ->
      prettySyntaxNode
        "Match"
        [ ("name", pretty name),
          ("processes", pretty procs)
        ]

data Process = Process
  {procActions :: [Located Action]}
  deriving (Eq, Ord, Show)

instance Pretty Process where
  pretty Process {..} =
    prettyLabelled "Process" $
      prettySyntaxList (fmap pretty procActions)

-- |  AST of type declarations.
data TypeDeclaration = TypeDeclaration
  { typeDeclName :: Located Identifier,
    typeDeclType :: Located Type
  }
  deriving (Eq, Show)

instance Pretty TypeDeclaration where
  pretty TypeDeclaration {..} =
    prettySyntaxNode
      "TypeDeclaration"
      [ ("name", pretty typeDeclName),
        ("type", pretty typeDeclType)
      ]

-- | AST of process declarations.
data ProcessDeclaration = ProcessDeclaration
  { procDeclName :: Located Identifier,
    procDeclType :: Located Sequent,
    procDeclBody :: Located Process
  }
  deriving (Eq, Show)

instance Pretty ProcessDeclaration where
  pretty ProcessDeclaration {..} =
    prettySyntaxNode
      "ProcessDeclaration"
      [ ("name", pretty procDeclName),
        ("type", pretty procDeclType),
        ("body", pretty procDeclBody)
      ]

-- | AST of function declarations.
data FunctionDeclaration = FunctionDeclaration
  { funcDeclName :: Located Identifier,
    funcDeclType :: Located Type,
    funcDeclBody :: Located Expression
  }
  deriving (Eq, Show)

instance Pretty FunctionDeclaration where
  pretty FunctionDeclaration {..} =
    prettySyntaxNode
      "FunctionDeclaration"
      [ ("name", pretty funcDeclName),
        ("type", pretty funcDeclType),
        ("body", pretty funcDeclBody)
      ]

-- | AST of declarations of any kind.
data Declaration
  = TypeDecl TypeDeclaration
  | ProcDecl ProcessDeclaration
  | FuncDecl FunctionDeclaration
  deriving (Eq, Show)

instance Pretty Declaration where
  pretty = \case
    TypeDecl typeDecl -> pretty typeDecl
    ProcDecl procDecl -> pretty procDecl
    FuncDecl funcDecl -> pretty funcDecl

data Module = Module
  { moduleDecls :: [Located Declaration]
  }
  deriving (Eq, Show)

instance Pretty Module where
  pretty Module {..} =
    prettySyntaxList (pretty <$> moduleDecls)
