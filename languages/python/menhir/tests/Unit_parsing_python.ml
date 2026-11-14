(*
   Copyright (c) 2022-2025 Semgrep Inc.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public License
   version 2.1 as published by the Free Software Foundation.

   This library is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the file
   LICENSE for more details.
*)
open Fpath_.Operators

let t = Testo.create

(*****************************************************************************)
(* Unit tests *)
(*****************************************************************************)

(* ran from the root of the semgrep repository *)
let tests_path = Fpath.v "tests"

let generic_program source =
  Hook.with_hook_set Flag_parsing.error_recovery false (fun () ->
      Parse_python.program_of_string source |> Python_to_generic.program)

let lazy_imports () =
  let source =
    "lazy import json, os.path as path\n\
     lazy from .tools import (load as read, save,)\n"
  in
  let stmts = generic_program source in
  Alcotest.(check int) "import count" 3 (List.length stmts);
  List.iter
    (fun stmt ->
      match stmt.AST_generic.s with
      | AST_generic.DirectiveStmt { d_attrs = [ KeywordAttr (Lazy, tok) ]; _ }
        ->
          Alcotest.(check string) "lazy token" "lazy" (Tok.content_of_tok tok)
      | _ -> Alcotest.fail "expected a lazy import directive")
    stmts

let comprehension_kinds () =
  List.iter
    (fun (source, kind) ->
      match generic_program source with
      | [
       { AST_generic.s = ExprStmt ({ e = Comprehension (actual, _); _ }, _); _ };
      ] ->
          Alcotest.(check bool) source true (actual = kind)
      | _ -> Alcotest.fail ("expected comprehension: " ^ source))
    AST_generic.
      [
        ("[*xs for xs in groups]", List);
        ("[*(1, x) for x in xs]", List);
        ("{*xs for xs in groups}", Set);
        ("{*(1, x) for x in xs}", Set);
        ("{**d for d in mappings}", Dict);
        ("(*xs for xs in groups)", Tuple);
        ("(*(1, x) for x in xs)", Tuple);
        ("{x for x in xs}", Set);
        ("{k: v for k, v in pairs}", Dict);
      ]

let tests =
  Testo.categorize "parsing_python"
    [
      t "template string prefixes" (fun () ->
          let prefixes =
            [ "t"; "T"; "tr"; "tR"; "Tr"; "TR"; "rt"; "rT"; "Rt"; "RT" ]
          in
          let quotes = [ "'"; "\""; "'''"; "\"\"\"" ] in
          List.iter
            (fun prefix ->
              List.iter
                (fun quote ->
                  let source = prefix ^ quote ^ "hello {name}" ^ quote in
                  match Parse_python.program_of_string source with
                  | [
                   AST_python.ExprStmt
                     (AST_python.InterpolatedString (start, parts, _));
                  ] ->
                      Alcotest.(check string)
                        "opening token" (prefix ^ quote)
                        (Tok.content_of_tok start);
                      Alcotest.(check int)
                        "literal and interpolation" 2 (List.length parts)
                  | _ -> Alcotest.fail ("not a template string: " ^ source))
                quotes)
            prefixes);
      t "interpolated string escapes" (fun () ->
          List.iter
            (fun (prefix, expected) ->
              List.iter
                (fun quote ->
                  let source = prefix ^ quote ^ "\\n\\t\\\\" ^ quote in
                  match Parse_python.program_of_string source with
                  | [
                   AST_python.ExprStmt
                     (AST_python.InterpolatedString
                        (_, [ AST_python.Literal (AST_python.Str (text, _)) ], _));
                  ] ->
                      Alcotest.(check string) source expected text
                  | _ -> Alcotest.fail ("not a literal string: " ^ source))
                [ "'"; "\""; "'''"; "\"\"\"" ])
            [
              ("t", "\n\t\\");
              ("f", "\n\t\\");
              ("rt", "\\n\\t\\\\");
              ("Tr", "\\n\\t\\\\");
              ("rf", "\\n\\t\\\\");
              ("Fr", "\\n\\t\\\\");
            ]);
      t "template string syntax" (fun () ->
          Parse_python.parse_program
            (tests_path / "parsing" / "python" / "t_strings.py")
          |> ignore);
      t "numeric and named escapes" (fun () ->
          List.iter
            (fun prefix ->
              List.iter
                (fun quote ->
                  let source =
                    prefix ^ quote
                    ^ "\\x41\\u0042\\U0001f600\\101\\N{LATIN CAPITAL LETTER \
                       C}\\N{LF}" ^ quote
                  in
                  let expression =
                    match Parse_python.program_of_string source with
                    | [ AST_python.ExprStmt expression ] -> expression
                    | _ -> Alcotest.fail source
                  in
                  let text =
                    match expression with
                    | AST_python.InterpolatedString (_, parts, _) ->
                        parts
                        |> List.map (function
                          | AST_python.Literal (AST_python.Str (text, _)) ->
                              text
                          | _ -> Alcotest.fail source)
                        |> String.concat ""
                    | AST_python.Literal (AST_python.Str (text, _))
                    | AST_python.EncodedStr ((text, _), _) ->
                        text
                    | _ -> Alcotest.fail source
                  in
                  Alcotest.(check string) source "AB😀AC\n" text)
                [ "'"; "\""; "'''"; "\"\"\"" ])
            [ ""; "u"; "f"; "t" ]);
      t "literal escape boundaries" (fun () ->
          List.iter
            (fun (prefix, source, expected) ->
              Alcotest.(check (result string string))
                source (Ok expected)
                (Python_string_literal.decode ~prefix source))
            [
              ("r", "\\n\\x41\\N{LF}", "\\n\\x41\\N{LF}");
              ("b", "\\377\\400\\u0041\\N{LF}", "\255\000\\u0041\\N{LF}");
              ("", "\\ud800", "\237\160\128");
              ("", "\\U0010ffff", "\244\143\191\191");
              ("", "\\N{CJK UNIFIED IDEOGRAPH-4E00}", "一");
              ("", "\\N{HANGUL SYLLABLE GA}", "가");
              ("", "\\N{latin capital letter a}", "A");
              ("", "\\q", "\\q");
              ("", "a\\\r\nb", "ab");
            ];
          List.iter
            (fun source ->
              match Python_string_literal.decode ~prefix:"" source with
              | Error _ -> ()
              | Ok _ -> Alcotest.fail ("accepted invalid escape: " ^ source))
            [ "\\x0"; "\\u123"; "\\U00110000"; "\\N{BOGUS}"; "\\" ]);
      t "Python 3.15 lazy imports" lazy_imports;
      t "Python 3.15 unpacking comprehension kinds" comprehension_kinds;
      t "dictionary spread container kinds" (fun () ->
          List.iter
            (fun source ->
              match generic_program source with
              | [
               {
                 AST_generic.s = ExprStmt ({ e = Container (Dict, _); _ }, _);
                 _;
               };
              ] ->
                  ()
              | _ -> Alcotest.fail ("expected dictionary: " ^ source))
            [ "{**mapping}"; "{'key': 1, **mapping}" ]);
      t "lazy remains an identifier" (fun () ->
          let stmts =
            generic_program
              "lazy = 1\n\
               lazy(lazy)\n\
               obj.lazy\n\
               import lazy as lazy\n\
               from lazy import lazy\n"
          in
          Alcotest.(check int) "statement count" 5 (List.length stmts));
      t "invalid lazy import prefixes" (fun () ->
          List.iter
            (fun source ->
              let rejected =
                try
                  generic_program source |> ignore;
                  false
                with
                | Parsing_error.Syntax_error _ -> true
              in
              Alcotest.(check bool) source true rejected)
            [
              "other import json";
              "other from json import loads";
              "lazy from json import *";
              "lazy from __future__ import annotations";
            ]);
      t "regression files" (fun () ->
          let dir = tests_path / "python" / "parsing" in
          let files = Common2.glob (dir / "*.py") in
          files
          |> List.iter (fun file ->
              Testutil.run !!file (fun () ->
                  Parse_python.parse_program file |> ignore)));
    ]
