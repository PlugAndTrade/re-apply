module Shell = struct
  type t = Command.t

  open K8s
  open Lwt.Infix

  let delimter = "---\n"

  let get_modify ~f resource from where =
    let get =
      resource |> Kubectl.get ~ns:from
      |> Kubectl.with_selectors [where]
      |> Kubectl.with_output ~output:"json"
    in
    let to_yaml item = item |> Conv.to_yaml |> Yaml.to_string_exn in
    let modify item = item |> KSOMod.normalize |> f in
    Command.read_a get >|= Yojson.Basic.from_string
    >|= KSOMod.map_items ~f:modify >|= List.map to_yaml
    >|= String.concat delimter

  let k_copy resource ({from; where; to_; _} : Ast.Op.Copy.t) =
    get_modify ~f:(KSOMod.namespace to_) resource from where

  let k_dup resource ({name_prefix; from; where; _} : Ast.Op.Duplicate.t) =
    get_modify ~f:(KSOMod.prefix_name name_prefix) resource from where

  let k_create resource ({name} : Ast.Op.Create.t) =
    let create =
      name |> Kubectl.create resource
      |> Kubectl.with_output ~output:"json"
      |> Kubectl.dry_run
    in
    let modify json =
      json |> KSOMod.normalize |> Conv.to_yaml |> Yaml.to_string_exn
    in
    Command.read_a create >|= Yojson.Basic.from_string >|= modify

  let to_kube (resource : Kubectl.kind) ({copy; create; duplicate} : Ast.Op.t)
      : string Lwt.t =
    match (copy, create, duplicate) with
    | Some cp, None, None -> k_copy resource cp
    | None, Some cr, None -> k_create resource cr
    | None, None, Some dup -> k_dup resource dup
    | _, _, _ -> Lwt.return "multi not implemented"

  let run ({kind; do_} : Ast.Resource.t) : unit Lwt.t =
    let kind = Kubectl.kind_of_string_exn kind in
    let ops = List.map (to_kube kind) do_ in
    let yaml =
      List.fold_left
        (fun acc op ->
          acc >>= fun acc -> op >|= fun op_s -> acc ^ delimter ^ op_s )
        (Lwt.return "") ops
    in
    yaml >>= Lwt_io.print

  let seq ({resources} : Ast.t) : unit Lwt.t =
    Lwt.join (List.map run resources)
end
