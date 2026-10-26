#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
export ERL_LIBS="$root/_build/default/lib${ERL_LIBS:+:$ERL_LIBS}"
build_dir="_build/manual-test/ebin"
mkdir -p "$build_dir"
escript priv/ibuild.escript
erlc -DTEST +debug_info -I include -o "$build_dir" src/*.erl test/*.erl
erl -noshell -pa "$build_dir" -eval '
    io:format("Erlang/OTP ~s~n", [erlang:system_info(otp_release)]),
    case eunit:test([localtime, localtime_dst, localtime_canada_tests, localtime_os_tests]) of
        ok -> halt(0);
        error -> halt(1)
    end.'
