type t = Lwt_process.command

open Lwt.Infix

module Infix = struct
  let ( % ) (cmd, args) arg = (cmd, Array.append args [|arg|])
end

let pp (_, command) =
  match Array.to_list command with
  | [] -> ""
  | cmd :: args -> Format.sprintf "%s %s" cmd (String.concat " " args)

let make command = ("", [|command|])

let exec = Lwt_process.exec
let read = Lwt_process.pread

let read_a ?(args=[||]) command =
  Lwt_process.pread (Array.fold_left Infix.(%) command args)

let rw proc stream =
    Lwt_io.write_lines proc#stdin stream
    >>= (fun _ -> Lwt_io.flush proc#stdin)
    >>= (fun _ -> Lwt_io.close proc#stdin)
    >>= (fun _ ->
        let stdout = Lwt_io.read_lines proc#stdout in

        Lwt_stream.fold (^) stdout ""
    )

let rw_stream stream command =
  Lwt_process.with_process_full command (fun proc -> rw proc stream)

let rw_string ?(sep='\n') data command =
  let stream = Lwt_stream.of_list (String.split_on_char sep data) in

  rw_stream stream command

module Kubectl = struct
  open Infix
  let exe = make "kubectl"

  type kind =
    | Configmap
    | Deployment
    | Ingress
    | Namespace
    | Secret
    | Service

  let kind_of_string s =
    match String.lowercase_ascii s with
    | "configmap" -> Some Configmap
    | "deployment" -> Some Deployment
    | "ingress" -> Some Ingress
    | "namespace" -> Some Namespace
    | "secret" -> Some Secret
    | "service" -> Some Service
    | _ -> None

  let kind_of_string_exn s  =
    match kind_of_string s with
    | Some kind -> kind
    | None -> failwith (Format.sprintf "unknown k8s kind %s" s)

  let kind_to_string = function
    | Configmap -> "Configmap"
    | Deployment -> "Deployment"
    | Ingress -> "Ingress"
    | Namespace -> "Namespace"
    | Secret -> "Secret"
    | Service -> "Service"

  let create resource name = exe % "create" % (kind_to_string resource) % name

  let delete resource name = exe % "delete" % (kind_to_string resource) % name

  let apply () = exe % "apply"

  let with_file cmd = cmd % "-f" % "-"

  let with_output cmd output = cmd % ("-o=" ^ output)

  let dry_run cmd = cmd % "--dry-run"
end
