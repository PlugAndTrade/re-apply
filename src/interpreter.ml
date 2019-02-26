module K8sModifers = struct
  open Modifier.Json

  let name n json =
    update "metadata" (
      function
        | Some m -> Some (update "namespace" (fun _ -> Some (`String n)) m)
        | None -> (Some (`Assoc []))
    ) json

  let namespace ns json =
    update "metadata" (
      function
        | Some m -> Some (update "namespace" (fun _ -> Some (`String ns)) m)
        | None -> (Some (`Assoc []))
    ) json

  let map_items ~f json =
    let open Yojson.Basic in
    json
    |> Modifier.Json.get "items"
    |> Util.map f
    |> Util.to_list

  let normalize json =
    let remove_in root json field =
      update root (function
          | Some r -> Some (remove field r)
          | None -> None
        ) json in
    let root_fields = ["status";] in
    let md_fields = ["selfLink"; "uuid";] in
    let ann_fields = ["kubectl.kubernetes.io/last-appliend-configuration"] in
    let j_root = List.fold_left (fun j field -> remove field j) json root_fields in
    let js_md = List.fold_left (remove_in "metadata") j_root md_fields in

    List.fold_left (remove_in "annotations") js_md ann_fields
end
module Shell = struct
  type t = Command.t

  let run (ast: Ast.t) : t =
    Command.Kubectl.apply ()

  let seq (ast: Ast.t) : t list =
    [Command.Kubectl.apply ()]
end
