-- | Parser.
module Language.Pion.Pass.Parsing
  ( Parser,
    runParser,
    ParseErrorBundle,
    ParseErrorRepr,
    parseModule,
    parseProcess,
    parseExpression,
    parsePattern,
    module',
    declaration,
    process,
    expression,
    pattern',
  )
where

import Control.Monad.Except
import Language.Pion.Lexer.Token (Stream)
import Language.Pion.Parser (declaration, expression, module', pattern', process)
import Language.Pion.Parser.Error
import Language.Pion.Parser.Monad (Parser, runParser)
import Language.Pion.SourceSpan (Located)
import Language.Pion.Syntax.Concrete

runParserReprError ::
  Monad m =>
  Parser a ->
  String ->
  Stream ->
  ExceptT ParseErrorRepr m a
runParserReprError parser name stream =
  withExceptT reprParseErrorBundle $
    runParser parser name stream

parseModule ::
  Monad m =>
  String ->
  Stream ->
  ExceptT ParseErrorRepr m Module
parseModule = runParserReprError module'

parseProcess ::
  Monad m =>
  String ->
  Stream ->
  ExceptT ParseErrorRepr m (Located Process)
parseProcess = runParserReprError process

parseExpression ::
  Monad m =>
  String ->
  Stream ->
  ExceptT ParseErrorRepr m (Located Expression)
parseExpression = runParserReprError expression

parsePattern ::
  Monad m =>
  String ->
  Stream ->
  ExceptT ParseErrorRepr m (Located Pattern)
parsePattern = runParserReprError pattern'
