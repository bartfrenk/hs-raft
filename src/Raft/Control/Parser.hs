{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE FlexibleContexts #-}

module Raft.Control.Parser
  ( module Raft.Control.Parser
  , ParseError
  ) where

import Control.Monad
import Data.Functor.Identity
import Text.Parsec

type Parser s = Parsec s ()

type CharStream s = Stream s Identity Char

data Command
  = Disable Int
  | Enable Int
  | Inspect Int
  | Quit
  deriving (Eq, Show)


whitespace :: CharStream s => Parser s ()
whitespace = void $ many $ oneOf " \t"

lexeme :: CharStream s => Parser s a -> Parser s a
lexeme p = p <* whitespace

integer :: CharStream s => Parser s Int
integer = lexeme $ read <$> many1 digit

control :: CharStream s => String -> Parser s ()
control s = lexeme $ void $ string ":" >> string s

disable :: CharStream s => Parser s Command
disable = Disable <$> (control "disable" *> integer)

enable :: CharStream s => Parser s Command
enable = Enable <$> (control "enable" *> integer)

inspect :: CharStream s => Parser s Command
inspect = Inspect <$> (control "inspect" *> integer)

quit :: CharStream s => Parser s Command
quit = control "quit" >> (pure Quit)

command :: CharStream s => Parser s Command
command = try disable <|> try enable <|> try inspect <|> quit <?> "command"

parse :: String -> Either ParseError Command
parse s = runParser command () "" s
