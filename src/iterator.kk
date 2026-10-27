module iterator

pub effect iterator<a>
  ctl yield(item : a) : ()

pub fun iter<item, e>(^iterator : () -> <iterator<item>|e> (), ^f : item -> e ()) : e ()
  with fun yield(item) f(item)
  iterator()
