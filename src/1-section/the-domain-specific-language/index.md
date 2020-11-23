---
title: The Domain Specific Language
description: An introduction to practical uses of the eDSL for OCurrent
authors:
- Patrick Ferris
date: 2020-11-20 13:38:10 +00:00
toc: true
resources: 
  - title: Adaptive Functional Programming
    description: The paper that the OCurrent eDSL for incrementalism is based on 
    url: https://www.cs.cmu.edu/~guyb/papers/popl02.pdf
---

Largely based on the very [excellent write-up](https://github.com/ocurrent/ocurrent/wiki/Internals) by Thomas Leonard.

An embedded domain specific language (eDSL) is a set of primitive values and functions written in a host-language to enable a programming experience of a new language. For those old enough, think `jQuery`. Within OCurrent the entire eDSL lives in the `Current_incr` package.

```ocaml env=ocurrent
# #require "current_incr"
# Current_incr.var
- : 'a -> 'a Current_incr.var = <fun>
```

As with a lot of things in OCaml, the eDSL takes on this *monadic* look as it wraps things up into its on type (thinks `'a list` or `'a Lwt.t`). 

## A simple arithmetic example 

The result of a `plus` operator has two dependencies, the operands. 

```ocaml env=ocurrent
# let plus a b = a + b 
val plus : int -> int -> int = <fun>
```

Nothing too surprising here, but what if we want to make this incremental so that it updates if `a` or `b` change. At this point `a` and `b` must be incremental values (i.e. `int Current_incr.t`).

```ocaml env=ocurrent
# let plus a b = 
  let open Current_incr in 
    read a (fun a -> read b (fun b -> write (a + b))) |> of_cc 
val plus : int Current_incr.t -> int Current_incr.t -> int Current_incr.t =
  <fun>
# let a = Current_incr.var 3
val a : int Current_incr.var = <abstr>
# let b = Current_incr.var 6
val b : int Current_incr.var = <abstr>
# let c = Current_incr.(plus (of_var a) (of_var b)) 
val c : int Current_incr.t = <abstr>
```

Now we can actually have a look at the value we computed using the `observe` function. Most importantly we can change the dependency variables `a` and `b` to a new integer and then run `propagate` and see the incrementalism happen before our eyes! 

```ocaml env=ocurrent
# Current_incr.observe c 
- : int = 9
# Current_incr.change a 10 
- : unit = ()
# Current_incr.propagate ()
- : unit = ()
# Current_incr.observe c 
- : int = 16
```

## Abstracting away 

The primitives for incrementalism are small and easy to understand, but not ideal for building larger applications. For one it would be nice to know ahead of time (statically) what are computation graph looks like. It would also be nice to incorporate `('a, 'b) Result.t` style exception handling because... things go wrong. 

This is exactly what `current.term` and eventually `Current` do! The `Term` module provides the static analysis and error handling whilst the final user-facing `Current` module provides asynchronous computations using `Lwt` and persistent logging. But first `Term`.

### Term Module

To build our usable `Term` module, we need to use the function `Current_term.Make`. It expects the simplest of module arguments: 

```ocaml env=term
# #require "current.term"
# #show Current_term
module Current_term :
  sig
    module S = Current_term__.S
    module Output = Current_term__.Output
    module Make : functor (Metadata : sig type t end) -> sig ... end
  end
```

Something with a type `t`. This is used (as the argument name helpfully points out) for `Metadata` information. For now it isn't too important. 

```ocaml env=term
# module Term = Current_term.Make (Unit)
module Term :
  sig
    type 'a t = 'a Current_term.Make(Unit).t
    type description = Current_term.Make(Unit).description
    val active : Current_term.Output.active -> 'a t
    val return : ?label:string -> 'a -> 'a t
    val fail : string -> 'a t
    val state :
      ?hidden:bool ->
      'a t ->
      ('a, [ `Active of Current_term.Output.active | `Msg of string ]) result
      t
    val catch : ?hidden:bool -> 'a t -> 'a Current_term.S.or_error t
    val ignore_value : 'a t -> unit t
    val of_output : 'a Current_term__.Output.t -> 'a t
    val map : ('a -> 'b) -> 'a t -> 'b t
    val map_error : (string -> string) -> 'a t -> 'a t
    val pair : 'a t -> 'b t -> ('a * 'b) t
    val list_map :
      (module Current_term.S.ORDERED with type t = 'a) ->
      ?collapse_key:string -> ('a t -> 'b t) -> 'a list t -> 'b list t
    val list_iter :
      (module Current_term.S.ORDERED with type t = 'a) ->
      ?collapse_key:string -> ('a t -> unit t) -> 'a list t -> unit t
    val list_seq : 'a t list -> 'a list t
    val option_map : ('a t -> 'b t) -> 'a option t -> 'b option t
    val option_seq : 'a t option -> 'a option t
    val all : unit t list -> unit t
    val all_labelled : (string * unit t) list -> unit t
    val gate : on:unit t -> 'a t -> 'a t
    val collapse : key:string -> value:string -> input:'b t -> 'a t -> 'a t
    val with_context : 'b t -> (unit -> 'a t) -> 'a t
    val bind : ?info:description -> ('a -> 'b t) -> 'a t -> 'b t
    type 'a primitive =
        ('a Current_term.Output.t * unit option) Current_incr.t
    val primitive : info:description -> ('a -> 'b primitive) -> 'a t -> 'b t
    val component : ('a, Format.formatter, unit, description) format4 -> 'a
    module Syntax :
      sig
        val ( let+ ) : 'a t -> ('a -> 'b) -> 'b t
        val ( and+ ) : 'a t -> 'b t -> ('a * 'b) t
        val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
        val ( let> ) : 'a t -> ('a -> 'b primitive) -> description -> 'b t
        val ( let** ) : 'a t -> ('a -> 'b t) -> description -> 'b t
        val ( and* ) : 'a t -> 'b t -> ('a * 'b) t
        val ( and> ) : 'a t -> 'b t -> ('a * 'b) t
      end
    module Analysis :
      sig
        val metadata : 'a t -> unit option t
        val pp : 'a t Fmt.t
        val pp_dot :
          env:(string * string) list ->
          collapse_link:(k:string -> v:string -> string option) ->
          job_info:(unit -> Current_term.Output.active option * string option) ->
          'a t Fmt.t
        val stats : 'a t -> Current_term.S.stats
      end
    module Executor :
      sig val run : 'a t -> 'a Current_term__.Output.t Current_incr.t end
  end
```

Now that we have a `Term` module we can rebuild our `plus` operator from earlier. 

```ocaml env=term
# open Term.Syntax
# let plus a b = 
  Term.component "PLUS" |> 
  let** a = a 
  and* b = b in 
    Term.return (a + b)
val plus : int Term.t -> int Term.t -> int Term.t = <fun>
```

Wahhh what's this crazy `let**` syntax? Since [OCaml 4.08](https://caml.inria.fr/pub/docs/manual-ocaml/bindingops.html) we've had binding operators. Just like you can define infix operators such as `( >>= )` these operators are very similar except they happen on the `let` bindings. 

```ocaml env=term
# Term.Syntax.( let** )
- : 'a Term.t -> ('a -> 'b Term.t) -> Term.description -> 'b Term.t = <fun>
```

As you can see it is just our friendly bind operator with a way for passing a description (more on that later). Give me something wrapped up in something and a function that works on the wrapped up thing, and I'll give you that function applied to the inner value wrapped up. 

```ocaml env=term
# let res = 
    let a = 3 |> Term.return ~label:"a" in 
    let b = 7 |> Term.return ~label:"a" in 
    Term.Executor.run (plus a b)
val res : int Current_term__.Output.t Current_incr.t = <abstr>
# Current_incr.observe res 
- : int Current_term__.Output.t = Ok 10
```

Here we also see the result type making it's way in. `Term` also gives us a way to fail too. 

```ocaml env=term
# Current_incr.observe (Term.fail "Woops!" |> Term.Executor.run)
- : 'a Current_term__.Output.t = Error (`Msg "Woops!")
```

Of course inside a pipeline we might not know if something has failed or not, in which case we can expose the underlying result using `Term.catch` and pattern-match on `Ok` and `Error`. 

### The Extra Metadata

One of the original goals of OCurrent was not only to build incremental pipelines but to expose them to users. The `Term` library (under the hood) is adding extra metadata and static analysis to be able to generate useful graphics and information. For example: 

```ocaml env=term
# let a = 3 |> Term.return ~label:"Operand 1" in 
  let b = 4 |> Term.return ~label:"Operand 2" in 
    Format.printf "%a@." Term.Analysis.pp (plus a b)
Operand 1
||
Operand 2 >>=
PLUS
- : unit = ()
```

Now, hopefully, it becomes apparent why the `component "PLUS"` and the `let**` operator were needed.

