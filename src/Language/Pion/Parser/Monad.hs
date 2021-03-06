-- | The parser monad.
module Language.Pion.Parser.Monad
  ( -- * Parser monad
    Parser,
    runParser,

    -- * Parsing primitives
    keyword,
    punctuation,
    connectiveType,
    modalityType,
    unitType,
    identifier,
    name,
    label,
    integerLiteral,
    floatLiteral,
    charLiteral,
    stringLiteral,

    -- * Parser combinators
    between,
    sepBy,
    branch,
    item,
    branches,
    items,
    conjunction,

    -- * Megaparsec reexports
    (<?>),
    try,

    -- * Source location
    located,
  )
where

import Control.Monad.Except
import Control.Monad.State
import Data.GADT.Compare
import Data.Semigroup (option)
import Data.Some
import Data.Type.Equality
import qualified Language.Pion.Lexer.Token as Token
import Language.Pion.Name
import Language.Pion.Parser.Error
import Language.Pion.SourceSpan
import Language.Pion.Syntax.Common
import Language.Pion.Type
import Text.Megaparsec (try, (<?>))
import qualified Text.Megaparsec as Mega

type Parser = Mega.ParsecT ParseError Token.Stream (State Mega.SourcePos)

-- | Run a parser on a token stream, lexed from a source with a given name.
runParser ::
  MonadError ParseErrorBundle m =>
  -- | The 'Parser' action to execute
  Parser a ->
  -- | The name of the input source, useful for error messages
  String ->
  -- | The token stream to parse
  Token.Stream ->
  -- | The result, wrapped into an error monad which can throw (pretty printed)
  -- parse errors
  m a
runParser parser sourceName stream =
  liftEither
    . flip evalState (Mega.initialPos sourceName)
    $ Mega.runParserT (parser <* Mega.eof) sourceName stream

-- | Consume a single lexeme and return the data associated with the matching
-- token, and fails if the next token represents a different lexeme.
lexeme :: Token.Lexeme a -> Parser a
lexeme expectedLexeme = do
  (tokenData, end) <- Mega.token matchToken expectedTokens
  option (pure ()) put end
  pure tokenData
  where
    matchToken (Located (Some Token.Token {..}) span) = do
      Refl <- geq tokenLexeme expectedLexeme
      pure (tokenData, spanEnd <$> span)
    expectedTokens = mempty

-- | Attach source information to a parse result.
located :: Parser a -> Parser (Located a)
located p = do
  start <- Mega.getSourcePos
  locNode <- p
  end <- get
  let locSpan = pure $ SourceSpan start end
  pure $ Located {..}

-- | Consume a keyword.
keyword :: Token.Keyword -> Parser ()
keyword = lexeme . Token.Keyword

-- | Consume a punctuation symbol.
punctuation :: Token.Punctuation -> Parser ()
punctuation = lexeme . Token.Punctuation

-- | Consume any simple lexeme (i.e. of type @Lexeme ()@).
anyLexeme :: (Enum a, Bounded a) => (a -> Token.Lexeme ()) -> Parser a
anyLexeme f = Mega.choice $ fmap (\x -> x <$ lexeme (f x)) enumerate

-- | Consume a connective type.
connectiveType :: Parser ConnectiveType
connectiveType = anyLexeme Token.ConnectiveType

-- | Consume a modality type.
modalityType :: Parser ModalityType
modalityType = anyLexeme Token.ModalityType

-- | Consume an unit type.
unitType :: Parser ConnectiveType
unitType = anyLexeme Token.UnitType

-- | Consume a delimiter, identified by its type and whether it is
-- supposed to be an opening or a closing delimiter.
delimiter :: Token.Delimiter -> Token.DelimiterType -> Parser ()
delimiter delim delimType = lexeme (Token.Delimiter delim delimType)

-- | Parse an element surrounded by opening and closing tokens of
-- the same delimiter type.
between :: Token.DelimiterType -> Parser a -> Parser a
between delimType =
  Mega.between
    (delimiter Token.Opening delimType)
    (delimiter Token.Closing delimType)

-- | Parse a branch from the parsers of the branch case and the branch value.
branch ::
  -- | Token between the branch case and the branch value
  Token.Punctuation ->
  -- | Parser for the branch case
  Parser (Located c) ->
  -- | Parser for the branch value
  Parser (Located a) ->
  -- | Resulting branch parser
  Parser (Branch c a)
branch assoc caseParser valueParser = do
  branchCase <- caseParser
  punctuation assoc
  branchValue <- valueParser
  pure Branch {..}

-- | Parse a branch without a label.
item :: Parser (Located a) -> Parser (Branch () a)
item valueParser = Branch (unknownLocation ()) <$> valueParser

-- | Parse many branches enclosed by a delimiter and separated by a given
-- punctuation symbol.
branches ::
  -- | Delimiter enclosing the branches
  Token.DelimiterType ->
  -- | Separator between each branch
  Token.Punctuation ->
  -- | Token between the case and value of each branch
  Token.Punctuation ->
  -- | Parser for the branch case
  Parser (Located c) ->
  -- | Parser for the branch value
  Parser (Located a) ->
  -- | Resulting parser of the list of branches
  Parser (Branches c a)
branches delim separator assoc caseParser valueParser =
  fmap Branches . between delim $
    branch assoc caseParser valueParser
      `sepBy` separator

-- | Parse many items enclosed by a delimiter and separated by a given
-- punctuation symbol.
items ::
  -- | Delimiter enclosing the items
  Token.DelimiterType ->
  -- | Separator between each item
  Token.Punctuation ->
  -- | Value parser
  Parser (Located a) ->
  -- | Resulting branch parser
  Parser (Branches () a)
items delim separator valueParser =
  fmap Branches . between delim $
    item valueParser
      `sepBy` separator

-- | Parse a conjunction.
conjunction ::
  -- | Delimiter enclosing labelled conjunctions
  Token.DelimiterType ->
  -- | Delimiter enclosing ordered conjunctions
  Token.DelimiterType ->
  -- | Token between the branch label and the value in the case of the
  -- labelled conjunction
  Token.Punctuation ->
  -- | Parser for branch values
  Parser (Located a) ->
  -- | Resulting conjunction
  Parser (Conjunction a)
conjunction labelledDelim orderedDelim assoc valueParser =
  -- If the delimiters are distinct then we don't need to backtrack
  tryIfSameDelimiters
    ( LabelledConjunction
        <$> branches
          labelledDelim
          Token.Comma
          assoc
          (located name)
          valueParser
    )
    <|> ( OrderedConjunction
            <$> items
              orderedDelim
              Token.Comma
              valueParser
        )
  where
    tryIfSameDelimiters
      | labelledDelim == orderedDelim = try
      | otherwise = id

-- | Parse a name.
name :: Parser Name
name = Name <$> lexeme Token.Identifier

-- | Parse a label.
label :: Parser Label
label = Label <$> lexeme Token.Identifier

-- | Parse an identifier.
identifier :: Parser Identifier
identifier = Identifier <$> lexeme Token.Identifier

-- | Consume a decimal integer literal.
integerLiteral :: Parser Integer
integerLiteral = lexeme Token.IntegerLiteral

-- | Consume a floating point literal.
floatLiteral :: Parser Double
floatLiteral = lexeme Token.FloatLiteral

-- | Consume a character literal.
charLiteral :: Parser Char
charLiteral = lexeme Token.CharLiteral

-- | Consume a string literal, which has to fit in one line.
stringLiteral :: Parser Text
stringLiteral = lexeme Token.StringLiteral

-- | @p `sepBy` sep@ parses zero or more occurences of @p@ separated
-- by the punctuation symbol @sep@.
sepBy :: Parser a -> Token.Punctuation -> Parser [a]
sepBy p sep = p `Mega.sepBy` punctuation sep
