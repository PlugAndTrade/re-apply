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
    type t =
      { from: string
      ; where: string
      ; map: Transform.t list
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

module Resource = struct
  type t = {kind: string; do_: Op.t list [@key "do"]}
  [@@deriving yojson {strict= false}]
end

type t = {resources: Resource.t list} [@@deriving yojson {strict= false}]

let default () = {resources= []}
