---
title: A Gatsby Site Deployer
description: Setup the entry point of the pipeline to watch Github and pull from it
  to get the latest content
authors:
- Patrick Ferris
date: 2020-11-21 00:02:33 +00:00
toc: true
resources: []
---

The first part of our pipeline is to pull content from Github. OCurrent is in now way limited to Github, but it is the only backend currently supported. So that's what we'll use. 

## Authentication 

In order to pull things from Github we'll have to authenticate in order to use the Github API. You will want to go to your profile `Settings > Developer Settings > Personal Access Tokens`.  Next you will want to generate a new token with support for access to your public repositories. 

## Fetching your repository 

We're almost done believe it or not! The next step is to actually use the OCurrent Github plugin (`Current_github`) to fetch the head commit of the main branch (`ref`). 

<!-- $MDX file=./deployer/deployer.ml,part=0 -->
```ocaml
module Gh = Current_github
module Git = Current_git
module Docker = Current_docker.Default

let fetch ~github ~repo () =
  let head = Gh.Api.head_commit github repo in
  let t = map Gh.Api.Commit.id head in
  Git.fetch t
```

The `~github` parameter is our *Api* value, we won't have to generate this as you will see later. And `~repo` is our repository which will eventually be in the form `username/repo` which the user can specify from the command-line. 

We first get the head of the repository using the `Api`'s exposed functionality and pull out the unique id using the `Current.map` function. Now we use the `Git` plugin to actually go get the specific head commit.

If we look at the [plugin code](https://github.com/ocurrent/ocurrent/blob/master/plugins/github/api.ml#L314) we can see that it defines a new component. This is what we see in the generated dependency graph. Not only that, but it is being **monitored** which allows OCurrent to propagate new values when the head commit changes (like if a new commit is pushed).

### A Note on Caching 

One of the big benefits of OCurrent pipelines is a smart use of caching. Luckily a lot of the plugins give you this out of the box. For example, the `Git.fetch` function is backed by the [fetch cache](https://github.com/ocurrent/ocurrent/blob/master/plugins/git/current_git.ml#L52). In the next tutorial on writing plugins we'll look at this more deeply, but you can see that the functor to a build a cache is relatively simple. 

```ocaml
# #require "current.cache"
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

## Building with Docker 

In order to build and run are Gatsby site we'll need two docker images: 

 - A *build* image in order to run `gatsby build` -- this will need NodeJS and yarn installed. We will use `node:12-buster` for this.
 - A *server* image with OCaml and opam installed. We will use `ocaml/opam:alpine-ocaml-4.11` for this, which is pushed to docker hub using an OCurrent pipeline!

The build process is quite simple: 

 1. Pull the docker images 
 2. Write a dockerfile in OCaml 
 3. Build the Dockerfile using the git repository we got earlier 
 4. Run the image we built

Thankfully, we can use the [Docker plugin](https://github.com/ocurrent/ocurrent/tree/master/plugins/docker) for all of this. 

<!-- $MDX file=./deployer/deployer.ml,part=2 -->
```ocaml
let build ~src () =
  let open Dockerfile in
  let dockerfile =
    let+ builder = Docker.pull ~schedule gatsby_builder
    and+ server = Docker.pull ~schedule gatsby_server in
    from ~alias:"build" (Docker.Image.hash builder)
    @@ workdir "/app"
    @@ run "yarn global add gatsby-cli"
    @@ copy ~src:[ "package.json" ] ~dst:"." ()
    @@ run "yarn"
    @@ copy ~src:[ "." ] ~dst:"." ()
    @@ run "gatsby build"
    @@ from (Docker.Image.hash server)
    @@ run "sudo apk update && sudo apk add m4"
    @@ run "opam install cohttp-lwt-unix"
    @@ copy ~from:"build" ~src:[ "/app/public" ] ~dst:"/pub" ()
    @@ workdir "/pub" @@ expose_port 8000
    @@ cmd "opam exec -- cohttp-server-lwt -p 8000 -s 0.0.0.0"
    |> fun d -> `Contents d
  in
  Docker.build ~pull:false ~dockerfile (`Git src)
```

We're using the [Dockerfile](https://github.com/avsm/ocaml-dockerfile) eDSL for writing Dockerfiles in OCaml which almost reads like a normal file. Using the Docker plugin's `pull` function we get both image and "expose" their values using the `let+` syntax. With `Docker.Image.hash` we use the hash version of the docker image which will be more reproducible than simply the name of the image. 

After that it should be mostly straightforward:

 - In the build image we copy in the `package.json` to install the write dependencies, then we copy in the main site and run `gatsby build` which outputs the website in `/app/public`. 
 - In the server image we install `cohttp-lwt-unix` to get the server and the copy the site from the build into `/pub`. We expose port `8000` and run the server on that port with host `0.0.0.0`. This will allows us to see the server running at `localhost:8000`. 

One aspect to make note of is the `schedule` parameter. We build this using the `Current_cache` module.

<!-- $MDX file=./deployer/deployer.ml,part=1 -->
```ocaml
let schedule = Current_cache.Schedule.v ~valid_for:(Duration.of_day 7) ()

let gatsby_builder = "node:12-buster"

let gatsby_server = "ocaml/opam:alpine-ocaml-4.11"
```

This tells our pipeline how often we should re-pull our Docker images. 

## The Final Pipeline

<!-- $MDX file=./deployer/deployer.ml,part=3 -->
```ocaml
let pipeline ~github ~repo () =
  let src = fetch ~github ~repo () in
  let image = build ~src () in
  Docker.run image ~run_args:[ "-p=8000:8000" ] ~args:[]
```

Our pipeline reuses the `fetch` and `build` we have already looked at. We pull that altogether in our `pipeline` function and run the Docker image we produced (with the additional port mapping parameter).

The last step is to wrap this pipeline up in the `Current.Engine` which we can run in a thread alongside a website for viewing our pipeline in action. The website just needs a `route list` which can be automatically generated from our `engine` value.

We then run this inside the main `lwt` thread. You could also use [this logging function](https://github.com/ocurrent/ocurrent/blob/master/examples/logging.ml#L36) if you want more information printed to the console. 

<!-- $MDX file=./deployer/deployer.ml,part=4 -->
```ocaml
let main config mode github repo =
  let engine = Current.Engine.create ~config (pipeline ~github ~repo) in
  let routes = Current_web.routes engine in
  let site =
    Current_web.Site.(v ~has_role:allow_all) ~name:"gatsby_deployer" routes
  in
  Lwt_main.run
    (Lwt.choose [ Current.Engine.thread engine; Current_web.run ~mode site ])
```

## Wrapping it up as a CLI tool

The final stage is to bring our pipeline together and use [Cmdliner](https://erratique.ch/software/cmdliner/doc/Cmdliner) to produce a useful CLI tool.

<!-- $MDX file=./deployer/deployer.ml,part=5 -->
```ocaml
(* Command-line parsing *)
open Cmdliner

let repo =
  Arg.required
  @@ Arg.pos 0 (Arg.some Gh.Repo_id.cmdliner) None
  @@ Arg.info ~doc:"The GitHub repository (owner/name) to monitor." ~docv:"REPO"
       []

let cmd =
  let doc = "Monitor a GitHub repository containing a Gatsby site." in
  ( Term.(
      const main $ Current.Config.cmdliner $ Current_web.cmdliner
      $ Gh.Api.cmdliner $ repo),
    Term.info "gatsby_deployer" ~doc )

let () = Term.(exit @@ eval cmd)
```

We can use the predefined arguments that the various `Current` module provide which add flags like `port` mapping. The only one we do provide is the `repo` parameter to specify which repository on Github we want to pull. We will also need to provide the authentication token from the beginning by pasting it into a file (here `.token`).

```
deployer --github-token-file=./.token patricoferris/gatsby-starter-default
```

And that's it! After running your pipeline go to `localhost:8080` to see your pipeline in action. Once it get's to the `run` component you should be able to go to `localhost:8000` and see your Gatsby site built and deployed on a Cohttp server! 
