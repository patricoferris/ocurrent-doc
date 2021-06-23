open Lwt.Infix

let () =
  Logs.set_level (Some Logs.Warning);
  Logs.set_reporter (Logs_fmt.reporter ())

let () =
  Lwt_main.run
    (let service = Server.local in
     Client.md_to_html service "## Hello" >>= fun reply ->
     Fmt.pr "Your HTML: %s" reply;
     Lwt.return_unit)
