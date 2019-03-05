open Command.Infix

let exe = Command.make "kubectl"

type kind = Configmap | Deployment | Ingress | Namespace | Secret | Service

let kind_of_string s =
  match String.lowercase_ascii s with
  | "configmap" -> Some Configmap
  | "deployment" -> Some Deployment
  | "ingress" -> Some Ingress
  | "namespace" -> Some Namespace
  | "secret" -> Some Secret
  | "service" -> Some Service
  | _ -> None

let kind_of_string_exn s =
  match kind_of_string s with
  | Some kind -> kind
  | None -> failwith (Format.sprintf "unknown k8s kind %s" s)

let kind_to_string = function
  | Configmap -> "configmap"
  | Deployment -> "deployment"
  | Ingress -> "ingress"
  | Namespace -> "namespace"
  | Secret -> "secret"
  | Service -> "service"

let get ?(ns = "default") resource =
  exe % "get" % kind_to_string resource % ("-n=" ^ ns)

let create resource name = exe % "create" % kind_to_string resource % name

let delete resource name = exe % "delete" % kind_to_string resource % name

let apply () = exe % "apply"

let with_file cmd = cmd % "-f" % "-"

let with_output ?(output = "json") cmd = cmd % ("-o=" ^ output)

let with_selectors selectors cmd = cmd % ("-l=" ^ String.concat "," selectors)

let with_field_selectors selectors cmd =
  cmd % ("--field-selector=" ^ String.concat "," selectors)

let dry_run cmd = cmd % "--dry-run"
