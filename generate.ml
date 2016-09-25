(*
 * Copyright (c) 2014 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

open Core.Std
open Lwt

let print_gpr_info pull =
  let open Github_t in
  let source_user = pull.pull_user.user_login in
  let head = pull.pull_head.branch_ref in
  let (source_user, source_repo, source_url) =
    match pull.pull_head.branch_repo with
      Some repo -> 
        let source_url =
          sprintf "https://github.com/%s/archive/%s.tar.gz"
           repo.repository_full_name head
	in
        let (a, b) = String.lsplit2_exn repo.repository_full_name ~on:'/' in
        (a, b, source_url)
    | None ->
        (source_user, "ocaml", sprintf "https://github.com/%s/ocaml/archive/%s.tar.gz" source_user head)
  in
  printf "%d %s %s %s %s %s\n%s\n" pull.pull_number source_user source_repo head pull.pull_base.branch_ref source_url pull.pull_title

let auth (token_name : string) = Lwt_main.run (
    Github_cookie_jar.init ()
    >>= fun jar ->
    Github_cookie_jar.get jar ~name:token_name
    >|= function
    | None -> eprintf "Use git-jar to create an `%s` token first.\n%!"
                token_name; exit (-1)
    | Some t -> t)

let get_pulls token user repo () =
  let open Github in
  let token =
    Option.map ~f:(fun token -> Token.of_string (auth token).Github_t.auth_token) token
  in
  let pulls = Pull.for_repo ?token ~user ~repo ~state:`Open () in
  Lwt_main.run (Monad.run (pulls |> Stream.to_list))
  |> List.iter ~f:print_gpr_info

let _ =
  Command.basic
    ~summary:"Generates an OPAM compiler remote for active GitHub OCaml PRs"
    Command.Spec.(
      empty
      +> flag "-k" ~doc:"TOKEN_NAME Name of the token in git-jar" (optional string)
      +> flag "-github-user" (optional_with_default "ocaml" string) ~doc:"string GitHub username"
      +> flag "-github-repo" (optional_with_default "ocaml" string) ~doc:"string GitHub repository"
    ) get_pulls
  |> Command.run
