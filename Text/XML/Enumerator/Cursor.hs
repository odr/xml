module Text.XML.Enumerator.Cursor
    ( Cursor
    , fromDocument
    , toCursor
    , cut
    , parent
    , precedingSibling
    , followingSibling
    , child
    , node
    , preceding
    , following
    , ancestor
    , descendant
    , (>=>)
    , orSelf
      -- not sure if we should keep these, at least good for testing
    , name
    ) where

import Data.XML.Types
import Control.Monad

-- TODO: Consider [Cursor] -> [Cursor]?
type Axis = Cursor -> [Cursor]

type DiffCursor = [Cursor] -> [Cursor]

data Cursor = Cursor
    { parent' :: Maybe Cursor
    , precedingSibling' :: DiffCursor
    , followingSibling' :: DiffCursor
    , child :: [Cursor]
    , node :: Node
    }

instance Show Cursor where
    show Cursor { node = n } = "Cursor @ " ++ show n

-- Idea: allow restricting the scope
cut :: Cursor -> Cursor
cut c = c { parent' = Nothing }

parent :: Axis
parent c = case parent' c of
             Nothing -> []
             Just p -> [p]

precedingSibling :: Axis
precedingSibling = ($ []) . precedingSibling'

followingSibling :: Axis
followingSibling = ($ []) . followingSibling'

fromDocument :: Document -> Cursor
fromDocument = toCursor . NodeElement . documentRoot

toCursor :: Node -> Cursor
toCursor = toCursor' Nothing id id

toCursor' :: Maybe Cursor -> DiffCursor -> DiffCursor -> Node -> Cursor
toCursor' par pre fol n =
    me
  where
    me = Cursor par pre fol chi n
    chi' =
        case n of
            NodeElement (Element _ _ x) -> x
            _ -> []
    chi = go id chi' []
    go _ [] = id
    go pre' (n':ns') =
        (:) me' . fol'
      where
        me' = toCursor' (Just me) pre' fol' n'
        fol' = go (pre' . (:) me') ns'

-- TODO: This currently does not include the children of preceding elements.
-- XPath's "preceding" does. It's probably good to have both.
preceding :: Axis
preceding c =
    go (precedingSibling' c) ++ (parent c >>= preceding')
  where
    preceding' x = x : preceding x
    go x =
        concatMap go' y -- FIXME very inefficient
      where
        y = x []
    go' x = reverse (x : descendant x)

-- TODO: This currently does not include the children of following elements.
-- XPath's "following" does. It's probably good to have both.
following :: Axis
following c =
    go (followingSibling' c) ++ (parent c >>= following)
  where
    go x =
        concatMap go' y -- FIXME very inefficient
      where
        y = x []
    go' x = x : descendant x

ancestor :: Axis
ancestor = parent >=> (\p -> p : ancestor p)

descendant :: Axis
descendant = child >=> (\c -> c : descendant c)

orSelf :: Axis -> Axis
orSelf ax c = c : ax c

name :: [Cursor] -> [Name]
name [] = []
name (Cursor { node = NodeElement (Element n _ _) }:cs) = n : name cs
name (_:cs) = name cs