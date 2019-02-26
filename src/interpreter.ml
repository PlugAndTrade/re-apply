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

  open Command
  open Lwt.Infix

  let to_kube (resource: Kubectl.kind) ({copy; create; duplicate;}: Ast.Op.t) : unit Lwt.t =
    match (copy, create, duplicate) with
    | (Some {from; where; to_; _}, None, None) ->
      let get =
        resource
        |> Kubectl.get ~ns:from
        |> Kubectl.with_selectors [where]
        |> Kubectl.with_output ~output: "json" in
      let _apply =
        ()
        |> Kubectl.apply
        |> Kubectl.with_output ~output: "json"
        |> Kubectl.with_file in

      (Command.read_a get)
      >|= Yojson.Basic.from_string
      >|= K8sModifers.map_items ~f: (fun item -> item |> K8sModifers.normalize |> (K8sModifers.namespace to_))
      >|= List.map (fun item -> item |> Ast.Conv.to_yaml |> Yaml.to_string_exn)
      >|= String.concat "---"
      (* >>= (Command.rw_string apply) *)
      >>= Lwt_io.print
    | (_, _, _) -> Lwt.return ()

  let run (resource : Ast.Resource.t) : t =
    let _kind = Kubectl.kind_of_string_exn resource.kind in
    Kubectl.apply ()

  let seq ({ resources }: Ast.t) : t list =
    ignore (resources);
    [(Kubectl.apply ())]
end
