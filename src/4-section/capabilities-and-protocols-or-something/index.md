---
title: Capabilities and protocols or something
description: A look into Capnp
authors:
- Patrick Ferris
date: 2020-12-04 12:27:04 +00:00
toc: true
resources: []
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

<!-- $MDX file=example/main.ml -->
```ocaml
module Schema = Schema.Make (Capnp.BytesMessage)

let () =
  let s = Schema.Builder.Config.init_root () in
  print_endline (Schema.Builder.Config.id_get s)
```

Which produces the `default_id` we specified from our capnp file. 


```bash
$ example/main.exe
default_id
```

## Cerealisation 

Pun intended. Serialisation... coming soon... 
