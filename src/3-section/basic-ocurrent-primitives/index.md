---
title: Basic OCurrent Primitives
description: A look at the core components of building OCurrent plugins
authors:
- Patrick Ferris
date: 2020-11-22 17:13:11 +00:00
toc: true
resources: []
---

In the [opening section](/introduction-to-incrementalism-in-ocurrent) we looked at foundational building blocks upon which OCurrent is built. In this section we will explore in more depth the interface must users will interact with when building their own OCurrent plugins including: 

 - Caching 
 - Monitoring 
 - Terms 

Each of these will then be used when we build the plugin in the next part of this tutorial.

## The Current Module

The `Current` module provides a lot of the functionality for glueing different parts of your plugin together. For example the `map` function. 

```ocaml env=ocurrent
# #require "current"
# Current.return
- : ?label:string -> 'a -> 'a Current.term = <fun>
# Current.map
- : ('a -> 'b) -> 'a Current.term -> 'b Current.term = <fun>
# Current.(return "hello " |> map (( ^ ) "world"))
- : string Current.term = <abstr>
```

### Jobs in OCurrent

A `Job.t` in OCurrent is exactly that, a task to be run. It carries about with it a lot of additional information for OCurrent to use such as its `priority` and its `start_time`.

## OCurrent Caching 

Caching is an important aspects to OCurrent pipelines. It can help reduce the amount of recomputation needed even if some input changes and it can really help for complex or lengthy operations (like pulling big docker images). In order to cache things we need to use the `Make` functor. 

```ocaml env=ocurrent
# #require "current.cache" 
# #show Current_cache.Make
module Make :
  functor (B : Current_cache.S.BUILDER) ->
    sig
      val get :
        ?schedule:Current_cache.Schedule.t ->
        B.t -> B.Key.t -> B.Value.t Current.Primitive.t
      val invalidate : B.Key.t -> unit
      val reset : db:bool -> unit
    end
```

From the signature of the returned module you can see we get something very cache-like with function for resetting, invalidating and getting items from our cache. But in order to have our cache we need to provide a builder. 

```ocaml env=ocurrent
# #show Current_cache.S.BUILDER
module type BUILDER =
  sig
    type t
    val id : string
    module Key : Current_cache.S.WITH_DIGEST
    module Value : Current_cache.S.WITH_MARSHAL
    val build : t -> Current.Job.t -> Key.t -> Value.t Current.or_error Lwt.t
    val pp : Key.t Fmt.t
    val auto_cancel : bool
  end
```

There are different aspects to our builder than we can see. Firstly, some configuration parameters: 

 - `id` -- a unique `id` for our `BUILDER`
 - `auto_cancel` -- a parameter which allows you to specify if an operation should be cancelled if no longer needed (`true`) or if only a user should be able to do it (`false`).

The `pp` function is just the standard `Format` style pretty-printing function. 

The more interesting parts are the modules `Key` and `Value` and finally the `build` function. 

### The Key Module

The Key module is used for looking up your entry in the cache much like a Hashtable. It must look like a `S.WITH_DIGEST`. 

```ocaml env=ocurrent
# #show Current_cache.S.WITH_DIGEST
module type WITH_DIGEST = sig type t val digest : t -> string end
```

Which is a very simple module with one function that takes a key value (`t`) and returns a unique string identifying that value in the cache. 

Often a nice way to do this is to convert you OCaml type to JSON with something like [ppx_deriving_yojson](https://github.com/ocaml-ppx/ppx_deriving_yojson).

### The Value Module

The value module is whatever the cache is storing and must look like a `S.WITH_MARSHAL`. 

```ocaml env=ocurrent
# #show Current_cache.S.WITH_MARSHAL
module type WITH_MARSHAL =
  sig type t val marshal : t -> string val unmarshal : string -> t end
```

Another relatively simple module but this time two functions are necessary -- `marshal` and `unmarshal`. You can think of these functions like `save` and `load`. You want to be able to turn your value type `t` into a `string` and then reverse the process. The idea being `unmarshal (marshal t) = t`. 

### The Build Function

Hopefully by exploring these two functions you get a good understanding of how the caching is going to work. The last step is the build function. This takes some configuration parameters but is mostly about generating a value from a key.

Let's have a look at how the `Git` plugin does it -- see [the repository here](https://github.com/ocurrent/ocurrent/blob/b5391e4ad2c1fd5c4de79665bd536559cec40d0d/plugins/git/current_git.ml#L22).

Ignore the code for working out the `level` for now, you see that a task is given to the supplied OCurrent `job`. The first thing it does is lock the repository that the `key` refers too. Then it tries to make a local copy if one does not already exist, it does so using `git_clone`. It then ensures the right `commit` is available, if not then it will be fetched before finally returning the commit. 
