(** {1:top Types } *)

type 'a gen
(** ['a gen] knows how to generate ['a] for use in Crowbar tests. *)

type ('k, 'res) gens =
  | [] : ('res, 'res) gens
  | (::) : 'a gen * ('k, 'res) gens -> ('a -> 'k, 'res) gens
(** multiple generators are passed to functions using a listlike syntax.
    for example, [map [int; int] (fun a b -> a + b)] *)

type 'a printer = Format.formatter -> 'a -> unit
(** pretty-printers for items generated by Crowbar; useful for the user in
    translating test failures into bugfixes. *)

(**/**)
(* re-export stdlib's list
   We only want to override [] syntax in the argument to Map *)
type nonrec +'a list = 'a list = [] | (::) of 'a * 'a list
(**/**)

(** {1:generators Generators } *)

(** {2:simple_generators Simple Generators } *)

val int : int gen
(** [int] generates an integer ranging from min_int to max_int, inclusive.
    If you need integers from a smaller domain, consider using {!range}. *)

val uint8 : int gen
(** [uint8] generates an unsigned byte, ranging from 0 to 255 inclusive. *)

val int8 : int gen
(** [int8] generates a signed byte, ranging from -128 to 127 inclusive. *)

val uint16 : int gen
(** [uint16] generates an unsigned 16-bit integer,
    ranging from 0 to 65535 inclusive. *)

val int16 : int gen
(** [int16] generates a signed 16-bit integer,
    ranging from -32768 to 32767 inclusive. *)

val int32 : Int32.t gen
(** [int32] generates a 32-bit signed integer. *)

val int64 : Int64.t gen
(** [int64] generates a 64-bit signed integer. *)

val float : float gen
(** [float] generates a double-precision floating-point number. *)

val bytes : string gen
(** [bytes] generates a string of arbitrary length (including zero-length strings).  *)

val bytes_fixed : int -> string gen
(** [bytes_fixed length] generates a string of the specified length.  *)

val bool : bool gen
(** [bool] generates a yes or no answer. *)

val range : ?min:int -> int -> int gen
(** [range ?min n] is a generator for integers between [min] (inclusive)
    and [min + n] (exclusive). Default [min] value is 0.
    [range ?min n] will raise [Invalid_argument] for [n <= 0].
*)

(** {2:generator_functions Functions on Generators } *)

val map : ('f, 'a) gens -> 'f -> 'a gen
(** [map gens map_fn] provides a means for creating generators using other
    generators' output.  For example, one might generate a Char.t from a
    {!uint8}:
    {[
      open Crowbar
      let char_gen : Char.t gen = map [uint8] Char.chr
    ]}
*)

val unlazy : 'a gen Lazy.t -> 'a gen
(** [unlazy gen] forces the generator [gen].  It is useful when defining
    generators for recursive data types:

    {[
      open Crowbar
      type a = A of int | Self of a
      let rec a_gen = lazy (
        choose [
          map [int] (fun i -> A i);
          map [(unlazy a_gen)] (fun s -> Self s);
        ])
      let lazy a_gen = a_gen
    ]}
*)

val fix : ('a gen -> 'a gen) -> 'a gen
(** [fix fn] applies the function [fn].  It is useful when defining generators
    for recursive data types:

    {[
      open Crowbar
      type a = A of int | Self of a
      let rec a_gen = fix (fun a_gen ->
          choose [
          map [int] (fun i -> A i);
          map [a_gen] (fun s -> Self s);
        ])
    ]}
    *)

val const : 'a -> 'a gen
(** [const a] always generates [a]. *)

val choose : 'a gen list -> 'a gen
(** [choose gens] chooses a generator arbitrarily from [gens]. *)

val option : 'a gen -> 'a option gen
(** [option gen] generates either [None] or [Some x], where [x] is the item
    generated by [gen]. *)

val pair : 'a gen -> 'b gen -> ('a * 'b) gen
(** [pair gena gen] generates (a, b)
    where [a] is generated by [gena] and [b] by [genb]. *)

val result : 'a gen -> 'b gen -> ('a, 'b) result gen
(** [result gena genb] generates either [Ok va] or [Error vb],
    where [va], [vb] are generated by [gena], [genb] respectively. *)

val list : 'a gen -> 'a list gen
(** [list gen] makes a generator for lists using [gen].  Lists may be empty; for
    non-empty lists, use {!list1}. *)

val list1 : 'a gen -> 'a list gen
(** [list1 gen] makes non-empty list generators. For potentially empty lists,
    use {!list}.*)

val concat_gen_list : string gen -> string gen list -> string gen
(** [concat_gen_list sep l] concatenates a list of string gen [l] inserting the
    separator [sep] between each *)

val with_printer : 'a printer -> 'a gen -> 'a gen
(** [with_printer printer gen] generates the same values as [gen].  If [gen]
    is used to create a failing test case and the test was reached by
    calling [check_eq] without [pp] set, [printer] will be used to print the
    failing test case. *)

val dynamic_bind : 'a gen -> ('a -> 'b gen) -> 'b gen
(** [dynamic_bind gen f] is a monadic bind, it allows to express the
   generation of a value whose generator itself depends on
   a previously generated value. This is in contrast with [map gen f],
   where no further generation happens in [f] after [gen] has
   generated an element.

   An typical example where this sort of dependencies is required is
   a serialization library exporting combinators letting you build
   values of the form ['a serializer]. You may want to test this
   library by first generating a pair of a serializer and generator
   ['a serializer * 'a gen] for arbitrary ['a], and then generating
   values of type ['a] depending on the (generated) generator to test
   the serializer. There is such an example in the
   [examples/serializer/] directory of the Crowbar implementation.

   Because the structure of a generator built with [dynamic_bind] is
   opaque/dynamic (it depends on generated values), the Crowbar
   library cannot analyze its statically
   (without generating anything) -- the generator is opaque to the
   library, hidden in a function. In particular, many optimizations or
   or fuzzing techniques based on generator analysis are
   impossible. As a client of the library, you should avoid
   [dynamic_bind] whenever it is not strictly required to express
   a given generator, so that you can take advantage of these features
   (present or future ones). Use the least powerful/complex
   combinators that suffice for your needs.
*)

(** {1:printing Printing } *)

(* Format.fprintf, renamed *)
val pp : Format.formatter -> ('a, Format.formatter, unit) format -> 'a
val pp_int : int printer
val pp_int32 : Int32.t printer
val pp_int64 : Int64.t printer
val pp_float : float printer
val pp_bool : bool printer
val pp_string : string printer
val pp_list : 'a printer -> 'a list printer
val pp_option : 'a printer -> 'a option printer

(** {1:testing Testing} *)

val add_test :
  ?name:string -> ('f, unit) gens -> 'f -> unit
(** [add_test name generators test_fn] adds [test_fn] to the list of eligible
    tests to be run when the program is invoked.  At runtime, random data will
    be sent to [generators] to create the input necessary to run [test_fn].  Any
    failures will be printed annotated with [name]. *)

(** {2:aborting Aborting Tests} *)

val guard : bool -> unit
(** [guard b] aborts a test if [b] is false.  The test will not be recorded
    or reported as a failure. *)

val bad_test : unit -> 'a
(** [bad_test ()] aborts a test.  The test will not be recorded or reported
    as a failure. *)

val nonetheless : 'a option -> 'a
(** [nonetheless o] aborts a test if [o] is None.  The test will not be recorded
    or reported as a failure. *)

(** {2:failing Failing} *)

val fail : string -> 'a
(** [fail message] generates a test failure and prints [message]. *)

val failf : ('a, Format.formatter, unit, _) format4 -> 'a
(** [failf format ...] generates a test failure and prints the message
    specified by the format string [format] and the following arguments.
    It is set up so that [%a] calls for an ['a printer] and an ['a] value. *)

(** {2:asserting Asserting Properties} *)

val check : bool -> unit
(** [check b] generates a test failure if [b] is false.  No useful information
    will be printed in this case. *)

val check_eq : ?pp:('a printer) -> ?cmp:('a -> 'a -> int) -> ?eq:('a -> 'a -> bool) ->
  'a -> 'a -> unit
(** [check_eq pp cmp eq x y] evaluates whether x and y are equal, and if they
    are not, raises a failure and prints an error message.
    Equality is evaluated as follows:

    {ol
    {- use a provided [eq]}
    {- if no [eq] is provided, use a provided [cmp]}
    {- if neither [eq] nor [cmp] is provided, use Pervasives.compare}}

    If [pp] is provided, use this to print [x] and [y] if they are not equal.
    If [pp] is not provided, a best-effort printer will be generated from the
    printers for primitive generators and any printers registered with
    [with_printer] and used. *)
