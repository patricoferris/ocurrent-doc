module Api = Schema.MakeRPC (Capnp_rpc_lwt)
open Lwt.Infix
open Capnp_rpc_lwt

let md_to_html t md =
  let module Client = Api.Client.MarkdownToHtml in
  let req, params =
    Capability.Request.create Client.Convert.Params.init_pointer
  in
  Client.Convert.Params.md_set params md;
  Capability.call_for_value_exn t Client.Convert.method_id req
  >|= Client.Convert.Results.html_get
