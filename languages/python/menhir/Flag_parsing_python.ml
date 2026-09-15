(*
   Copyright (c) 2026 Semgrep Inc.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public License
   version 2.1 as published by the Free Software Foundation.

   This library is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the file
   LICENSE for more details.
*)

(* Flags specific to the Python parser in this directory.
 *
 * Unlike Parse_python.parsing_mode, which is threaded explicitly through the
 * lexer, these flags are for the few places (currently only the generated
 * menhir parser) that cannot receive the information as a parameter.
 *)

(* Whether the grammar should use the Python 2 reading of the constructs whose
 * meaning changed in Python 3.
 *
 * Currently this only affects 'except A, e:', which in Python 2 was the
 * equivalent of 'except A as e:' but which, since Python 3.14 (PEP 758),
 * means 'except (A, e):', i.e. a tuple of exception types.
 *
 * This is set by Parse_python.ml around the calls to the generated parser
 * when the parsing mode is Parse_python.Python2.
 *)
let python2 = Hook.create false
