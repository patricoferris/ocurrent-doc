module Api = Schema.MakeRPC (Capnp_rpc_lwt)
open Capnp_rpc_lwt

let local =
  let module Server = Api.Service.MarkdownToHtml in
  Server.local
  @@ object
       inherit Server.service

       method convert_impl params release =
         let open Server.Convert in
         let md = Params.md_get params in
         (* Free up unused parameters -- backward capatability *)
         release ();
         let response, result = Service.Response.create Results.init_pointer in
         Results.html_set result Omd.(of_string md |> to_html);
         Service.return response
     end
