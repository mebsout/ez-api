module Resto = Resto1

open StringCompat

module TYPES : sig

  type ip_info = {
    ip_ip : string;
    mutable ip_last : float;
    mutable ip_nb : int;
    ip_country : string * string;
  }

  type http_version = HTTP_1_0 | HTTP_1_1

  type request_body =
    | BodyString of (* content-type *) string option * (* content *) string

  type request = {
    req_version : http_version;
    req_headers : string list StringMap.t;
    mutable req_params : string list StringMap.t;
    mutable req_body : request_body;
    (* Modify this field if you want to send back specific headers. *)
    mutable rep_headers : (string * string) list;
  }

  type arg_kind = REQUIRED of string | OPTIONAL of string

  type param_type = PARAM_INT | PARAM_STRING | PARAM_BOOL

  type arg_value =
    | I of int
    | S of string
    | LS of string list

  type base_url = BASE of string
  type url = URL of string
end

open TYPES

type request = TYPES.request
type params = TYPES.request (* TODO: remove this alias *)
type ip_info = TYPES.ip_info
type base_url = TYPES.base_url
type arg_value = TYPES.arg_value
type url = TYPES.url

type path =
  | ROOT
  | CONCAT of path * string
  | ENDARG of path * Resto.Arg.descr

type param = {
  param_value : string;
  param_name : string option;
  param_descr : string option;
  param_type : TYPES.param_type;
  param_required : bool;
  param_examples : string list
}

type service_doc = {
  doc_id : int; (* uniq service identifier *)
  doc_name : string option;
  doc_descr : string option;
  doc_path : path;
  doc_params : param list;
  mutable doc_registered : bool;
  mutable doc_sample : (base_url -> url);
  doc_section : section;
  doc_input : Json_schema.schema Lazy.t;
  doc_output : Json_schema.schema Lazy.t;
}

and section = {
  section_name : string;
  mutable section_docs : service_doc list;
}

(* All our services use 'params' as 'prefix of the service, and
   'unit' as 'input of the service (i.e. no input) *)
type ('params, 'params2, 'input, 'output) service

type 'output service0 = (request, unit, unit, 'output) service
type ('arg,'output) service1 =
  (request * 'arg, unit * 'arg, unit, 'output) service

type ('input,'output) post_service0 =
  (request, unit, 'input, 'output) service
type ('arg,'input,'output) post_service1 =
  (request * 'arg, unit * 'arg, 'input, 'output) service

type ('a, 'b) p

val request :
  ?version:http_version ->
  ?headers:string list StringMap.t ->
  ?body: request_body ->
  (string * string list) list -> request

val add_params : request -> (string * string list) list -> unit

val section : string -> section

module Path : sig
  val root : (request,unit) p
  val (//) : ('a,'b) p -> string -> ('a,'b) p
  val (/:) : ('a,'b) p -> 'c Resto.Arg.arg * 'c -> ('a * 'c,'b * 'c) p
end

module Param : sig
  val string : ?name:string -> ?descr:string -> ?required:bool
    -> ?examples:string list -> string -> param
  val int : ?name:string -> ?descr:string -> ?required:bool
    -> ?examples:string list -> string -> param
  val bool : ?name:string -> ?descr:string -> ?required:bool
    -> ?examples:string list -> string -> param
end

val arg_string : ?descr:string -> string -> string -> string Resto.Arg.arg * string
val arg_int : ?descr:string -> string -> int -> int Resto.Arg.arg * int


val service :
  ?section: section ->
  ?name: string -> (* name of additionnal doc. in [md_of_services] map *)
  ?descr: string ->
  output: 'output Json_encoding.encoding ->
  ?params:param list ->
  ('b, 'c) p ->
  ('b, 'c, unit, 'output) service

val post_service :
  ?section: section ->
  ?name: string -> (* name of additionnal doc. in [md_of_services] map *)
  ?descr: string ->
  input:'input Json_encoding.encoding ->
  output: 'output Json_encoding.encoding ->
  ?params:param list ->
  ('b, 'c) p ->
  ('b, 'c, 'input, 'output) service

val register :
  ('a, 'b, 'input, 'output) service ->
    (request, 'a, 'input, 'output) Resto.service *
    (request, 'a, unit, 'output) Resto.service

val all_services_registered : unit -> bool

val warnings : (string -> unit) -> unit

val forge0 :
  base_url -> (_, unit, _ ,_) service -> (param * arg_value) list -> url
val forge1 :
  base_url -> (_, unit * 'a, _, _) service ->
  'a -> (param * arg_value) list -> url
val printf : base_url -> ('a, unit, string, url) format4 -> 'a

(* [md_of_services map] creates a documentation from all the declared
  services. We should probably use a specific type [doc] to gather
  services in different groups. *)
val md_of_services :
  ?section:section ->
  ?base_url:base_url ->
  (string * string) list -> string

(* return a comma-concatenation of the occurrences of the argument *)
val find_param :
  param -> request -> string option
val find_params : param -> request -> string list option

val section_name : section -> string
val id : _ service -> int
val nservices : unit -> int

val services_doc_map : (service_doc -> 'a) -> 'a list

(* [service_to_readable service_doc] gives the information contained in the
   service_doc under usual types format: ie (id, name, path, registered, params)
   where params is a list of the params given under the string format:
   (value, name. descr, type) *)
val service_to_readable : service_doc ->
  (int * string * string * bool *
   (string * string * string * string) list)

val services : unit -> string array

exception ResultNotfound

val encode_args :
  ('a, 'b, 'c, 'd) service ->
  url -> (param * arg_value) list -> string

val service_input : (_, _, 'input, _) service -> 'input Json_encoding.encoding
val service_output : (_, _, _, 'output) service -> 'output Json_encoding.encoding

(* swagger *)
val paths_of_sections : ?docs:((string * string * string) list) ->
  section list ->
  (string * Ezjsonm.value) list * (string * Ezjsonm.value) list
