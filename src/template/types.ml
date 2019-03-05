module Kind = struct
  type t = Configmap | Deployment | Ingress | Namespace | Secret | Service
  [@@deriving yojson {strict= false}]
end

module Patch = struct
  type t = {op: string; path: string; value: Yojson.Safe.json}
  [@@deriving yojson {strict= false}]
end

module Op = struct
  module Copy = struct
    type t =
      { from: string
      ; where: string option [@default None]
      ; where_field: string option [@key "whereField"] [@default None]
      ; to_: string [@key "to"]
      ; patch: Patch.t list option [@default None] }
    [@@deriving yojson {strict= false}]
  end

  module Duplicate = struct
    type t =
      { from: string
      ; where: string option [@default None]
      ; where_field: string option [@key "whereField"] [@default None]
      ; patch: Patch.t list option [@default None]
      ; name_prefix: string [@key "namePrefix"] }
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

module Remote = struct
  type t = {kind: string; do_: Op.t list [@key "do"]}
  [@@deriving yojson {strict= false}]
end

module Local = struct
  type t = {path: string; patch: Patch.t list option [@default None]}
  [@@deriving yojson {strict= false}]
end

type t =
  {remote: Remote.t list [@default []]; local: Local.t list [@default []]}
[@@deriving yojson {strict= false}]

let default () = {remote= []; local= []}
