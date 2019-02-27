module K8s = struct
  open Modifier.Json

  let name n json =
    update "metadata"
      (function
        | Some m -> Some (update "name" (fun _ -> Some (`String n)) m)
        | None -> Some (`Assoc []))
      json

  let prefix_name prefix json =
    update "metadata"
      (function
        | Some m ->
            Some
              (update "name"
                 (function
                   | Some (`String name) -> Some (`String (prefix ^ name))
                   | Some s -> Some s
                   | None -> None)
                 m)
        | None -> Some (`Assoc []))
      json

  let namespace ns json =
    update "metadata"
      (function
        | Some m -> Some (update "namespace" (fun _ -> Some (`String ns)) m)
        | None -> Some (`Assoc []))
      json

  let map_items ~f json =
    let open Yojson.Basic in
    json |> Modifier.Json.get "items" |> Util.map f |> Util.to_list

  let remove_fields path fields json =
    List.fold_left
      (fun acc field -> update_in ~f:(remove field) path acc)
      json fields

  let normalize json =
    List.fold_left (fun j field -> remove field j) json ["status"]
    |> remove_fields ["metadata"]
         ["selfLink"; "uid"; "creationTimestamp"; "resourceVersion"]
    |> remove_fields
         ["metadata"; "annotations"]
         ["kubectl.kubernetes.io/last-applied-configuration"]
end

module Shell = struct
  type t = Command.t

  open Command
  open Lwt.Infix

  let get_modify ~f resource from where =
    let get =
      resource |> Kubectl.get ~ns:from
      |> Kubectl.with_selectors [where]
      |> Kubectl.with_output ~output:"json"
    in
    let _apply =
      () |> Kubectl.apply
      |> Kubectl.with_output ~output:"json"
      |> Kubectl.with_file
    in
    let delimter = "---\n" in
    let to_yaml item = item |> Conv.to_yaml |> Yaml.to_string_exn in
    let modify item = item |> K8s.normalize |> f in
    Command.read_a get >|= Yojson.Basic.from_string >|= K8s.map_items ~f:modify
    >|= List.map to_yaml >|= String.concat delimter >>= Lwt_io.print

  let k_copy resource ({from; where; to_; _} : Ast.Op.Copy.t) =
    get_modify ~f:(K8s.namespace to_) resource from where

  let k_dup resource ({name_prefix; from; where} : Ast.Op.Duplicate.t) =
    get_modify ~f:(K8s.prefix_name name_prefix) resource from where

  let k_create resource ({name} : Ast.Op.Create.t) =
    let create =
      name |> Kubectl.create resource
      |> Kubectl.with_output ~output:"json"
      |> Kubectl.dry_run
    in
    let modify json =
      json |> K8s.normalize |> Conv.to_yaml |> Yaml.to_string_exn
    in
    ignore (print_endline (Command.pp create)) ;
    Command.read_a create >|= Yojson.Basic.from_string >|= modify
    >>= Lwt_io.print

  let to_kube (resource : Kubectl.kind) ({copy; create; duplicate} : Ast.Op.t)
      : unit Lwt.t =
    match (copy, create, duplicate) with
    | Some cp, None, None -> k_copy resource cp
    | None, Some cr, None -> k_create resource cr
    | None, None, Some dup -> k_dup resource dup
    | _, _, _ -> Lwt.return "multi not implemented" >>= Lwt_io.print

  let run (resource : Ast.Resource.t) : t =
    let _kind = Kubectl.kind_of_string_exn resource.kind in
    Kubectl.apply ()

  let seq ({resources} : Ast.t) : t list = ignore resources ; [Kubectl.apply ()]
end
