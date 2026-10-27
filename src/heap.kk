module heap


type min-policy 
  MinPolicy

type max-policy
  MaxPolicy

fun max-policy/policy(self, other) : order
  match (self, other)
    (Node(_, _ ,_, priority-a), Node(_, _ ,_, priority-b)) -> priority-a.cmp(priority-b)
    (Empty, Node(_)) -> Lt
    (Node(_), Empty) -> Gt
    (Empty, Empty)   -> Eq
    // What could possibly go here?
    _                -> Eq

type heap<p, a>
  Empty
  Node(left : heap<p, a>, inner : a, right : heap<p, a>, priority : int)

alias min-heap<a> = heap<min-policy, a>

pub fun heap/empty() : heap<p, a>
  Empty
 
pub fun heap/is-empty(self : heap<p, a>) : bool
  match self 
    Empty -> True 
    _     -> False

pub fun heap/head(self : heap<p, a>) : maybe<a>
  match self 
    Node(_, inner, _, _) -> Just(inner) 
    Empty                    -> Nothing

pub fun heap/length(self : heap<p, a>) : int
  match self 
    Empty -> 0
    Node(left, _, right, _) -> 1 + left.length + right.length

pub fun heap/add(self : heap<p, a>, inner : a, ?(<) : (a, a) -> bool) : div heap<p, a>
  match self
    Empty -> Node(Empty, inner, Empty, 1)
    Node(l, elt, r, priority) -> 
      if inner < elt then 
        (Node(l, inner, r, priority)).add(elt)
      else if l.length < r.length then 
        Node(l.add(inner), elt, r, priority + 1)
      else 
        Node(l, elt, r.add(inner), priority + 1)

pub fun maybe/is-just-and<a>(self : maybe<a>, ^pred : a -> bool) : bool 
  match self 
    Just(x) -> pred(x)
    Nothing -> False

// pub fun heap/replace<p, a>(self : heap<p, a>, inner : a, ?(<) : (a, a) -> bool) : heap<p, a>
//   match self 
//     Node(Empty, _, Empty, priority) -> Node(Empty, inner, Empty, priority)
//     Node(l, _, Empty, priority) -> 
//       match l.head
//         Just(x) | inner < x -> Node(l, inner, Empty, priority)
//         Just(x) -> Node(l.replace(inner), x, Empty, priority)
//         Nothing -> throw("TODO")


