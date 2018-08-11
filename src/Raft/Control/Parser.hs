{-# LANGUAGE ConstraintKinds  #-}
{-# LANGUAGE FlexibleContexts #-}

module Raft.Control.Parser
  ( module Raft.Control.Parser
  , ParseError
  ) where

import           Control.Monad
import           Data.Functor.Identity
import           Text.Parsec hiding (parse)

import           Raft.Types            (Role (..))

type Parser s = Parsec s ()

type CharStream s = Stream s Identity Char

data Command
  = Disable Int
  | Enable Int
  | SetRole Role
            Int
  | Inspect (Maybe Int)
  | SendCommand String
                Int -- TODO: Better to parametrize the command type
  | Quit
  deriving (Eq, Show)

whitespace :: CharStream s => Parser s ()
whitespace = void $ many $ oneOf " \t"

lexeme :: CharStream s => Parser s a -> Parser s a
lexeme p = p <* whitespace

integer :: CharStream s => Parser s Int
integer = lexeme $ read <$> many1 digit

control :: CharStream s => String -> Parser s ()
control s = lexeme $ void $ string "\\" >> string s

disable :: CharStream s => Parser s Command
disable = Disable <$> (control "disable" *> integer)

enable :: CharStream s => Parser s Command
enable = Enable <$> (control "enable" *> integer)

inspect :: CharStream s => Parser s Command
inspect = Inspect <$> (control "inspect" *> optionMaybe integer)

quit :: CharStream s => Parser s Command
quit = control "quit" >> (pure Quit)

setRole :: CharStream s => Parser s Command
setRole = control "setRole" *> (SetRole <$> role <*> integer)
  where
    role = candidate <|> follower <|> leader <?> "role"
    leader = lexeme (string "leader") *> pure Leader
    follower = lexeme (string "follower") *> pure Follower
    candidate = lexeme (string "candidate") *> pure Candidate

sendCommand :: CharStream s => Parser s Command
sendCommand = control "send" *> (SendCommand <$> cmd <*> integer)
  where
    cmd = lexeme $ many1 (noneOf " \t")

command :: CharStream s => Parser s (Maybe Command)
command =
  Just <$>
  (try disable <|> try enable <|> try inspect <|> try sendCommand <|> setRole <|>
   quit) <|>
  (whitespace *> pure Nothing) <?> "command"

parse :: String -> Either ParseError (Maybe Command)
parse s = runParser command () "" s
