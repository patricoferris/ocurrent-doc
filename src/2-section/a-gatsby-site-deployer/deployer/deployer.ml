open Current
open Current.Syntax

[@@@part "0"]

module Gh = Current_github
module Git = Current_git
module Docker = Current_docker.Default

let fetch ~github ~repo () =
  let head = Gh.Api.head_commit github repo in
  let t = map Gh.Api.Commit.id head in
  Git.fetch t

[@@@part "1"]

let schedule = Current_cache.Schedule.v ~valid_for:(Duration.of_day 7) ()

let gatsby_builder = "node:12-buster"

let gatsby_server = "ocaml/opam:alpine-ocaml-4.11"

[@@@part "2"]

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

[@@@part "3"]

let pipeline ~github ~repo () =
  let src = fetch ~github ~repo () in
  let image = build ~src () in
  Docker.run image ~run_args:[ "-p=8000:8000" ] ~args:[]

[@@@part "4"]

let main config mode github repo =
  let engine = Current.Engine.create ~config (pipeline ~github ~repo) in
  let routes = Current_web.routes engine in
  let site =
    Current_web.Site.(v ~has_role:allow_all) ~name:"gatsby_deployer" routes
  in
  Lwt_main.run
    (Lwt.choose [ Current.Engine.thread engine; Current_web.run ~mode site ])

[@@@part "5"]

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
