module R = Rresult.R
module OS = Base.Os
module Conv = Base.Conv
module Types = Types

module Env = struct
  type t = (string * string) list

  let empty = []

  let add_arg env arg = env @ [arg]

  let to_json envs = `O (List.map (fun (k, v) -> (k, `String v)) envs)

  let interpolate (_envs : t) (template : string) = template
end

let of_yaml path =
  let open R in
  Fpath.of_string path >>| OS.read_file >>| Env.interpolate Env.empty
  >>= Yaml.yaml_of_string >>= Yaml.to_json >>| Conv.to_yojson
  >>= fun json ->
  match Types.of_yojson json with
  | Ok json -> Rresult.R.return json
  | Error e -> Rresult.Error (`Msg e)
