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

let read_a ?(args = [||]) command =
  Lwt_process.pread (Array.fold_left Infix.( % ) command args)

let rw proc stream =
  Lwt_io.write_lines proc#stdin stream
  >>= (fun _ -> Lwt_io.flush proc#stdin)
  >>= (fun _ -> Lwt_io.close proc#stdin)
  >>= fun _ ->
  let stdout = Lwt_io.read_lines proc#stdout in
  Lwt_stream.fold ( ^ ) stdout ""

let rw_stream stream command =
  Lwt_process.with_process_full command (fun proc -> rw proc stream)

let rw_string ?(sep = '\n') command data =
  let stream = Lwt_stream.of_list (String.split_on_char sep data) in
  rw_stream stream command

let escape_string s = Format.sprintf "\"%s\"" s
