---
title: Capabilities and protocols or something
description: A look into Capnp
authors:
- Patrick Ferris
date: 2020-12-04 12:27:04 +00:00
toc: true
resources: 
  - title: High Performance Browser Networking
    description: Ilya Grigorik's fantastic book covering many aspects of internet/networking protocols inluding TLS, HTTP/2, WebRTC etc. 
    url: https://hpbn.co/
---

Almost everything in the OCurrent world communicates using [Cap'n Proto](https://capnproto.org/). The only reference to why it is called this was from [this hackernews thread](https://news.ycombinator.com/item?id=12471266).

> Or you can also think of it as "Cap-and-Proto". Which is an intentional pun ("capabilities and protocols", or something).

From the introduction we get a "jargon-rich" description of what we're dealing with: 

> Cap’n Proto is an insanely fast data interchange format and capability-based RPC system. Think JSON, except binary.

So let's start with RPC. 

## Remote Procedure Calls 

Typically when thinking of two communicating devices, we think of a request and response framework. You ask a webserver for a web-page and it responds. RPC wants the programmer (or whoever) to *invoke* the *procedure* on the other machine. 

The RPC system sits between the caller and the callee marshalling (encoding) and un-marshalling (decoding) arguments and return values. Some programming languages have their own internal RPC system (like Java's remote method invocation). More commonly there are protocol specifications (gRPC, Cap'n Proto etc.) that act as a platform-agnostic scheme to perform RPC regardless of where you are running (OS or programming language).

Martin Kleppmann does a great job [explaining RPC systems](https://www.youtube.com/watch?v=S2osKiqQG9s) in a series of undergraduate lectures. 

## Cap'n Proto Schema 

The Cap'n Proto schema is used to describe the layout of data. Unlike JSON, the schema is strongly-typed and not self-describing. Strongly-typed refers to the inability to implicitly convert between unrelated types i.e. no `"hello" + 3`. Non self-describing means we need a schema to understand the structure. 

[The schema section of Cap'n Proto](https://capnproto.org/language.html) does a perfect job of describing in great detail all of the different parts of its specification. Here's an example from a file called `schema.capnp`: 

<!-- $MDX file=./example/schema.capnp -->
```
@0xd7de9e0850af18b2; 
# A unique identification string

struct Config {
  id @0 : Text = "default_id"; # field with default value
  workers @1 : Int8;
  port @2 : Int16; #max 65535 ports
}
```

The `@n` tags show you the protocol has evolved over time with each number field incrementing the count. Each field of the struct is also given a type from [the built-in](https://capnproto.org/language.html#built-in-types) types. We won't look into everything that can be defined here, but instead move on to the OCaml mapping. 

For a real-world example, have a look at [OCluster's API schema](https://github.com/ocurrent/ocluster/blob/master/api/schema.capnp).

### Cap'n Proto in OCaml

Thanks to [@pelzlpj](https://github.com/capnproto/capnp-ocaml) there are OCaml "bindings" to manipulate Cap'n Proto messages in OCaml. From a schema, the relevant source can be generated using `capnp compiler -o ocaml`. As will be described later, this build command is implemented as a custom rule in the dune file.

```bash
$ cat example/schema.mli
[@@@ocaml.warning "-27-32-37-60"]

type ro = Capnp.Message.ro
type rw = Capnp.Message.rw

module type S = sig
  module MessageWrapper : Capnp.RPC.S
  type 'cap message_t = 'cap MessageWrapper.Message.t
  type 'a reader_t = 'a MessageWrapper.StructStorage.reader_t
  type 'a builder_t = 'a MessageWrapper.StructStorage.builder_t


  module Reader : sig
    type array_t
    type builder_array_t
    type pointer_t = ro MessageWrapper.Slice.t option
    val of_pointer : pointer_t -> 'a reader_t
    module Config : sig
      type struct_t = [`Config_ac6bb9103d76a422]
      type t = struct_t reader_t
      val has_id : t -> bool
      val id_get : t -> string
      val workers_get : t -> int
      val port_get : t -> int
      val of_message : 'cap message_t -> t
      val of_builder : struct_t builder_t -> t
    end
  end

  module Builder : sig
    type array_t = Reader.builder_array_t
    type reader_array_t = Reader.array_t
    type pointer_t = rw MessageWrapper.Slice.t
    module Config : sig
      type struct_t = [`Config_ac6bb9103d76a422]
      type t = struct_t builder_t
      val has_id : t -> bool
      val id_get : t -> string
      val id_set : t -> string -> unit
      val workers_get : t -> int
      val workers_set_exn : t -> int -> unit
      val port_get : t -> int
      val port_set_exn : t -> int -> unit
      val of_message : rw message_t -> t
      val to_message : t -> rw message_t
      val to_reader : t -> struct_t reader_t
      val init_root : ?message_size:int -> unit -> t
      val init_pointer : pointer_t -> t
    end
  end
end

module MakeRPC(MessageWrapper : Capnp.RPC.S) : sig
  include S with module MessageWrapper = MessageWrapper

  module Client : sig
  end

  module Service : sig
  end
end

module Make(M : Capnp.MessageSig.S) : module type of MakeRPC(Capnp.RPC.None(M))
```

Let's deconstruct that a bit. Our schema is defined within the main `S` module. Using the `MessageWrapper` module, the: 

> generated code is functorized over the underlying message format 

which is made clear by the `MakeRPC` functor and the use of that module in `S`. There are two main modules that `S` exposes as structs are mapped to modules: 

  1. `Reader` -- provides read-only operations over the struct
  2. `Builder` -- provides read-write operations over the struct 

To access our schema in OCaml code, it is conventional to generate it at build-time using dune. 

<!-- $MDX file=example/dune -->
```
(executable
 (name main)
 (flags
  (:standard -w -53-55))
 (libraries capnp-rpc-lwt))

(rule
 (targets schema.ml schema.mli)
 (deps schema.capnp)
 (action
  (run capnp compile -o %{bin:capnpc-ocaml} %{deps})))
```

Here we have a very simple custom rule to generate the `schema.ml{i}` files from the `.capnp` file using the compiler. Note as well the need for the warning flags to be disabled. This is because `capnp-ocaml` tries to do inlining that only works on a `+flambda` branch of the compiler. 

<!-- $MDX file=example/main.ml,part=0 -->
```ocaml
module Schema = Schema.Make (Capnp.BytesMessage)

let () =
  let s = Schema.Builder.Config.init_root () in
  print_endline (Schema.Builder.Config.id_get s);
  Schema.Builder.Config.id_set s "new_id";
  print_endline (Schema.Builder.Config.id_get s)
```

This small example uses the generated `schema.ml` module to produce the `default_id` we specified from our capnp file. But we can also set the `id` just as easily and print the new one. 

```bash
$ example/main.exe
default_id
new_id
```

## Capnp RPC 

### Time-travelling with Promises

Now that we've covered the basics of Capnp schema generation we can move on to the [RPC protocol](https://capnproto.org/rpc.html). One of the big selling-points is that Capnp-RPC is a *time-travelling RPC* (or promise-pipelining). If you are familiar with OCaml's Lwt library (or promises in Javascript) you should be familiar with the idea of promises. 

As a recap, promises are potentially pending results of computation. The neat thing about them is that you can carry on your computation (building up a series of callbacks) even without the actual data. In this way you can achieve a form of concurrency. Capnp-RPC provides a similar idea when results and arguments of RPC calls stay contained within the same client-server connection.

In addition to this, Capnp-RPC uses *promise pipelining*. In essence we can call further methods of unresolved promises in a [pipeline](http://www.erights.org/elib/distrib/pipeline.html) fashion without incurring the cost of extra round-trip times. 

### Capabilities 

Most people are familiar with the idea of capabilities from access control matrices (or similar). Here, the idea is quite simple. Our system is made up of a set of subjects `S`, a set of objects `O` and a set of access rights `A`. A capability associates a subset of access rights to a particular object `o` with a subject `s`. [Vitally](http://en.wikipedia.org/wiki/Capability-based_security): 

> ... a capability-based ... system must use a capability to access an object 

The interface described previously is in fact a capability -- it is both linked to some object and grants access to that object by nature of being able to call it. 

### Capnp-RPC in OCluster

We'll touch on this some more in later sections, but the main idea is that OCluster needs a method to communicate between machines (for example the scheduler and the workers). [Ilya Grigorik's High Performance Browser Networking book](https://hpbn.co/transport-layer-security-tls/) has a brilliant chapter on TLS. Communication happens over *Transport Layer Security* (TLS) but within the `.cap` files there are fingerprints and a secret. 

