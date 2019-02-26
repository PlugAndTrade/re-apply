module R = Rresult.R
module OS = Os

module Conv = struct
  let to_yojson (ezjson : Yaml.value) : Yojson.Safe.json =
    let rec fn = function
      | `Null -> `Null
      | `Bool b -> `Bool b
      | `Float f -> `Float f
      | `String value -> `String value
      | `A l -> `List (List.map fn l)
      | `O l -> `Assoc (List.map (fun (k, v) -> (k, fn v)) l)
    in
    fn ezjson

  let to_yaml (json : Yojson.Basic.json) : Yaml.value =
    let rec fn = function
      | `Null -> `Null
      | `Bool b -> `Bool b
      | `Float f -> `Float f
      | `Int i -> `String (string_of_int i)
      | `String value -> `String value
      | `List l -> `A (List.map fn l)
      | `Assoc l -> `O (List.map (fun (k, v) -> (k, fn v)) l)
    in
    fn json
end

module Kind = struct
  type t = Configmap | Deployment | Ingress | Namespace | Secret | Service
  [@@deriving yojson {strict= false}]
end

module Op = struct
  module Transform = struct
    type t = {op: string; path: string; value: string}
    [@@deriving yojson {strict= false}]
  end

  module Copy = struct
    type t =
      { from: string
      ; where: string
      ; to_: string [@key "to"]
      ; map: Transform.t list }
    [@@deriving yojson {strict= false}]
  end

  module Duplicate = struct
    type t = {from: string; where: string; map: Transform.t list}
    [@@deriving yojson {strict= false}]
  end

  module Create = struct
    type t = {name: string} [@@deriving yojson {strict= false}]
  end

  type t =
    { copy: (Copy.t option[@default None])
    ; create: (Create.t option[@default None])
    ; duplicate: (Duplicate.t option[@default None]) }
  [@@deriving yojson {strict= false}]
end

module Resource = struct
  type t = {kind: string; do_: Op.t list [@key "do"]}
  [@@deriving yojson {strict= false}]
end

type t = {resources: Resource.t list} [@@deriving yojson {strict= false}]

let default () = {resources= []}

let of_yaml path =
  let open OS.Infix in
  let open R in
  Fpath.of_string path >>| OS.read_file >>= Yaml.yaml_of_string
  >>= Yaml.to_json >>| Conv.to_yojson >>| of_yojson
  >>| function Ok json -> json | Error _ -> default ()

(* >>| (function
   *   | Ok json -> json |> to_yojson |> Yojson.Safe.to_string
   *   | Error e -> (Format.sprintf "Error: %s" e))
   * <|> "WTF" *)
(* >>| t_of_sexp
   * <|> (make ()) *)
