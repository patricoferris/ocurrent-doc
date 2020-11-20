---
title: A High Level Interface
description: The high-level OCurrent interface for building pipelines
authors:
- Patrick Ferris
date: 2020-11-20 17:20:30 +00:00
toc: false
resources: []
---

We have seen the underlying mechanism for providing incrementalism in OCurrent (`Current_incr` and `Term`). Now we'll look at the high-level, user-facing library where we have the full-power of asynchronous programming to build pipelines.

## Current 

`Current` is the intended library for users to interact with. We'll take a look at its core modules which provided a meaningful way to program incrementally and asynchronously. But first... let's rewrite `plus` in `Current`. 

```ocaml env=ocurrent
# #require "current"
# open Current.Syntax 
# let plus a b = 
    let open Current in 
    component "PLUS" |> 
    let** a = a 
    and* b = b in 
      return (a + b)
val plus : int Current.term -> int Current.term -> int Current.term = <fun>
```

And now we can run this inside the `Current.Engine` on a thread.  The major difference now is how we generate our changeable inputs, the `a` and the `b` from before. Now we have to use the functor.

```ocaml env=ocurrent
# module CInt = Current.Var (struct 
  include Int 
  let pp = Format.pp_print_int 
  end)
module CInt :
  sig
    type t
    val get : t -> int Current.term
    val create : name:string -> int Current_term.Output.t -> t
    val set : t -> int Current_term.Output.t -> unit
    val update :
      t -> (int Current_term.Output.t -> int Current_term.Output.t) -> unit
  end
```

