%%%-------------------------------------------------------------------
%%% @author Pawel Chrzaszcz
%%% @copyright (C) 2013, Erlang Solutions Ltd.
%%% @doc Script generator callback module for dtrace
%%%
%%% @end
%%% Created : 3 Jul 2013 by pawel.chrzaszcz@erlang-solutions.com
%%%-------------------------------------------------------------------
-module(tracerl_gen_dtrace).

-include("tracerl_util.hrl").

-import(tracerl_gen_util, [sep/2, sep_t/3, sep_t/4, tag/2, tag/3, sep_f/3,
                           insert_args/2]).

-compile(export_all).

%%-----------------------------------------------------------------------------
%% API
%%-----------------------------------------------------------------------------
script(ScriptSrc) ->
    tracerl_gen:script(?MODULE, ScriptSrc).

script(ScriptSrc, Node) ->
    tracerl_gen:script(?MODULE, ScriptSrc, Node).

%%-----------------------------------------------------------------------------
%% tracerl_gen callbacks
%%-----------------------------------------------------------------------------
init_state(State) ->
    State.

%%-----------------------------------------------------------------------------
%% tracerl_gen callbacks - pass 1: preprocess
%%-----------------------------------------------------------------------------

%%-----------------------------------------------------------------------------
%% tracerl_gen callbacks - pass 2: generate
%%-----------------------------------------------------------------------------
generate(Probes, State) ->
    {sep_t(probe, after_probe, Probes, "\n"), State}.

probe({probe, Point, Statements}, State) ->
    {[{probe_point, Point}, " ", {st, {group, Statements}}, "\n"], State};
probe({probe, Point, Predicate, Statements}, State) ->
    {[{probe_point, Point},
      "\n/ ", {op, Predicate}, " /\n",
      {st, {group, Statements}}, "\n"], State}.

probe_point('begin', State) ->
    {"BEGIN", State};
probe_point('end', State) ->
    {"END", State};
probe_point({tick, N}, State) ->
    {["tick-", ?i2l(N), "s"], State};
probe_point(Function, State = #gen_state{pid = OSPid})
  when is_integer(hd(Function)) ->
    {["erlang", OSPid, ":::", Function],
     insert_args(Function, State)}.

st_body({set, Name, Keys}, State) ->
    {stat_body(sum, Name, Keys, "0"), State};
st_body({count, Name, Keys}, State) ->
    {stat_body(count, Name, Keys, ""), State};
st_body({Type, Name, Keys, Value}, State)
  when Type == sum; Type == min; Type == max; Type == avg ->
    {stat_body(Type, Name, Keys, {op, Value}), State};
st_body({reset, [H|T]}, State) ->
    {sep([{st_body, {reset, H}} |
          [{align, {st_body, {reset, Name}}} || Name <- T]], ";\n"), State};
st_body({reset, Name}, State) ->
    {["trunc(@", ?a2l(Name), ")"], State};
st_body({group, Items}, State) ->
    {["{\n",
      {indent, outdent, [sep_t(st, Items, ";\n"), ";\n"]},
      {align, "}"}], State};
st_body(exit, State) ->
    {["exit(0)"], State};
st_body({printa, Format, Args}, State = #gen_state{stats = Stats}) ->
    ArgSpec = [printa_arg_spec(Arg, Stats) || Arg <- Args],
    {["printa(", sep([{op,Format} | ArgSpec], ", "), ")"], State};
st_body({printf, Format}, State) ->
    st_body({printf, Format, []}, State);
st_body({printf, Format, Args}, State) ->
    {["printf(", sep_t(op, [Format | Args], ", "), ")"], State};
st_body(_, _) ->
    false.

stat_body(Type, Name, Keys, Value) ->
    [$@, ?a2l(Name), key_expr(Type, Keys), " = ", ?a2l(Type),
     "(", Value, ")"].

key_expr(Type, []) when Type /= set -> "";
key_expr(_Type, Keys) -> ["[", sep_t(op, Keys, ", "), "]"].

printa_arg_spec(Arg, Stats) when is_atom(Arg) ->
    true = orddict:is_key(Arg, Stats),
    [$@ | ?a2l(Arg)];
printa_arg_spec(Arg, _Stats) ->
    {op, Arg}.

op({arg_str, N}, State) when is_integer(N), N > 0 ->
    {["copyinstr(arg", ?i2l(N-1), ")"], State};
op({arg, N}, State) when is_integer(N), N > 0 ->
    {["arg", ?i2l(N-1)], State};
op(_, _) ->
    false.
