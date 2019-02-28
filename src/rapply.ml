open Template.Types
open Base
open K8s
open Lwt.Infix
module R = Rresult.R

let delimter = "---\n"

module Ctx = struct
  type t = {template_path: string; env: Template.Env.t}

  let make path =
    let open Template in
    let vars =
      [ ("GIT_USER", Base.Os.Git.user ())
      ; ("GIT_BRANCH", Base.Os.Git.current_branch ())
      ; ("GIT_COMMIT", Base.Os.Git.current_commit ()) ]
    in
    let env = List.fold_left Env.add_arg Env.empty vars in
    {template_path= path; env}
end

module Kube = struct
  let patch ({op; path; value} : Op.Patch.t) =
    let open Base.Modifier in
    let p = JsonPatch.make_p ~value:(Some value) op path in
    match JsonPatch.from_patch p with
    | Some patch -> JsonPatch.patch patch
    | None -> failwith (Format.sprintf "The provided patch is invalid")

  let get_modify ~f resource from where patches =
    let get =
      resource |> Kubectl.get ~ns:from
      |> Kubectl.with_selectors [where]
      |> Kubectl.with_output ~output:"json"
    in
    let to_yaml item = item |> Conv.to_yaml |> Yaml.to_string_exn in
    let modify item =
      let json = item |> KSO.normalize |> f in
      let ps = List.map patch patches in
      let patched =
        List.fold_left (fun j f -> f j) (Conv.basic_to_safe json) ps
      in
      Yojson.Safe.to_basic patched
    in
    Command.read_a get >|= Yojson.Basic.from_string >|= KSO.map_items ~f:modify
    >|= List.map to_yaml >|= String.concat delimter

  let copy resource ({from; where; to_; patch} : Op.Copy.t) =
    get_modify ~f:(KSO.namespace to_) resource from where patch

  let dup resource ({name_prefix; from; where; patch} : Op.Duplicate.t) =
    get_modify ~f:(KSO.prefix_name name_prefix) resource from where patch

  let create resource ({name} : Op.Create.t) =
    let create =
      name |> Kubectl.create resource
      |> Kubectl.with_output ~output:"json"
      |> Kubectl.dry_run
    in
    let modify json =
      json |> KSO.normalize |> Conv.to_yaml |> Yaml.to_string_exn
    in
    Command.read_a create >|= Yojson.Basic.from_string >|= modify
end

let to_kubetcl (resource : Kubectl.kind) ({copy; create; duplicate} : Op.t) :
    string Lwt.t =
  match (copy, create, duplicate) with
  | Some cp, None, None -> Kube.copy resource cp
  | None, Some cr, None -> Kube.create resource cr
  | None, None, Some dup -> Kube.dup resource dup
  | _, _, _ -> Lwt.return "multi not implemented"

let run_op ({kind; do_} : Resource.t) : unit Lwt.t =
  let kind = Kubectl.kind_of_string_exn kind in
  let ops = List.map (to_kubetcl kind) do_ in
  let yaml =
    List.fold_left
      (fun acc op ->
        acc >>= fun acc -> op >|= fun op_s -> acc ^ delimter ^ op_s )
      (Lwt.return "") ops
  in
  yaml >>= Lwt_io.print

let seq ({resources} : Template.Types.t) : unit Lwt.t =
  Lwt.join (List.map run_op resources)

let run path =
  let open R in
  let ctx = Ctx.make path in
  Template.of_yaml ctx.template_path ~env:ctx.env >>| seq
