open Template.Types
open Base
open K8s
open Lwt.Infix
module R = Rresult.R

let delimter = "\n---\n"

module Ctx = struct
  type t = {template_path: string; env: Template.Env.t}

  let make path envs =
    let open Template in
    let default_vars =
      [ ("GIT_USER", Base.Os.Git.user ())
      ; ("GIT_BRANCH", Base.Os.Git.current_branch ())
      ; ("GIT_COMMIT", Base.Os.Git.current_commit ()) ]
    in
    let vars =
      envs
      |> List.map (fun e ->
             match String.split_on_char '=' e with
             | [k; v] -> (k, v)
             | _ -> ("", "") )
      |> List.filter (fun (k, _) -> k != "")
    in
    let env = List.fold_left Env.add_arg Env.empty (vars @ default_vars) in
    {template_path= path; env}
end

module Kube = struct
  let patch ({op; path; value} : Patch.t) =
    let open Base.Modifier in
    let p = JsonPatch.make_p ~value:(Some value) op path in
    match JsonPatch.from_patch p with
    | Some patch -> JsonPatch.patch patch
    | None -> failwith (Format.sprintf "The provided patch is invalid")

  let get_modify ~f resource from where where_field patches =
    let get = Kubectl.get ~ns:from resource in
    let get =
      match (where, where_field) with
      | Some where, None -> get |> Kubectl.with_selectors [where]
      | None, Some where_field ->
          get |> Kubectl.with_field_selectors [where_field]
      | Some where, Some where_field ->
          get
          |> Kubectl.with_selectors [where]
          |> Kubectl.with_field_selectors [where_field]
      | None, None -> get
    in
    let get_with_output = get |> Kubectl.with_output ~output:"json" in
    let encode item = item |> Yojson.Basic.pretty_to_string in
    let modify item =
      let json = item |> KSO.normalize |> f in
      match patches with
      | Some ps ->
          List.map patch ps
          |> List.fold_left (fun j f -> f j) (Conv.basic_to_safe json)
          |> Yojson.Safe.to_basic
      | None -> json
    in
    Command.read_a get_with_output
    >|= Yojson.Basic.from_string >|= KSO.map_items ~f:modify
    >|= List.map encode >|= String.concat delimter

  let copy resource ({from; where; where_field; to_; patch} : Op.Copy.t) =
    get_modify ~f:(KSO.namespace to_) resource from where where_field patch

  let dup resource
      ({name_prefix; from; where; where_field; patch} : Op.Duplicate.t) =
    get_modify
      ~f:(KSO.prefix_name name_prefix)
      resource from where where_field patch

  let create resource ({name} : Op.Create.t) =
    let create =
      name |> Kubectl.create resource
      |> Kubectl.with_output ~output:"json"
      |> Kubectl.dry_run
    in
    let modify json =
      json |> KSO.normalize |> Yojson.Basic.pretty_to_string
    in
    Command.read_a create >|= Yojson.Basic.from_string >|= modify
end

module Local = struct
  open R

  let read_and_modify ({path; patch} : Local.t) : string Lwt.t =
    let maybe_json =
      Fpath.of_string path >>| Base.Os.read_file >>= Yaml.yaml_of_string
      >>= Yaml.to_json >>| Conv.to_yojson
    in
    let encode j = j |> Yojson.Safe.to_basic |> Yojson.Basic.pretty_to_string in
    match (maybe_json, patch) with
    | Ok json, Some ps ->
        List.map Kube.patch ps
        |> List.fold_left (fun j f -> f j) json
        |> encode
        |> Lwt.return
    | Ok j, _ -> j |> encode |> Lwt.return
    | Error (`Msg e), _ ->
        failwith
          (Format.sprintf "Local file conversion %s failed with %s" path e)
end

let to_kubetcl (resource : Kubectl.kind) ({copy; create; duplicate} : Op.t) :
    string Lwt.t =
  match (copy, create, duplicate) with
  | Some cp, None, None -> Kube.copy resource cp
  | None, Some cr, None -> Kube.create resource cr
  | None, None, Some dup -> Kube.dup resource dup
  | None, None, None -> failwith (Format.sprintf "At least one 'do' operation required for %s" (Kubectl.kind_to_string resource))
  | _, _, _ -> failwith "Multiple 'do' operations not supported"

let run_local local = List.map Local.read_and_modify local

let run_op ({kind; do_} : Remote.t) : string Lwt.t list =
  List.map (to_kubetcl (Kubectl.kind_of_string_exn kind)) do_

let seq ({remote; local} : Template.Types.t) : unit Lwt.t =
  let locals = run_local local in
  let ops = locals @ List.flatten (List.map run_op remote) in
  let yaml =
    List.fold_left
      (fun acc op ->
        acc >>= fun acc -> op >|= fun op_s -> acc ^ delimter ^ op_s )
      (Lwt.return "") ops
  in
  yaml >>= Lwt_io.print

let run path envs =
  let open R in
  let ctx = Ctx.make path envs in
  Template.of_yaml ctx.template_path ~env:ctx.env >>| seq
