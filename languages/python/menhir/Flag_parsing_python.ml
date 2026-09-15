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

(* Flags for the parts of the Python parser that cannot receive the
 * Parse_python.parsing_mode as a parameter (i.e., the generated grammar). *)

(* Use the Python 2 reading of constructs whose meaning changed in Python 3
 * (currently just 'except A, e:'). Set by Parse_python around the parser
 * calls when the parsing mode is Python2. *)
let python2 = Hook.create false
