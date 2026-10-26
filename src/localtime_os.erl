%% OS zoneinfo provider. No fallback to the bundled recurring-rule snapshot.
-module(localtime_os).
-include_lib("elocaltime/include/elocaltime.hrl").
-export([utc_to_local/2, utc_to_local_dst/2, local_to_utc/2, tz_name/2, tz_shift/2, dst/2]).

utc_to_local(Date, Zone) ->
    case absolute(Date, Zone) of
        {ok, #absolute_lookup{date = Local}} -> Local;
        Error -> Error
    end.

%% qdate's explicit prefer_daylight API historically applies its preference
%% to both source and target zones. Keep that wrapper convention here rather
%% than making the direct UTC instant conversion return ambiguous results.
utc_to_local_dst(Date, Zone) ->
    case absolute(Date, Zone) of
        {ok, #absolute_lookup{date = Local, is_dst = false}} ->
            case local_infos(Local, Zone) of
                {ok, [{Standard, #absolute_lookup{is_dst = false}},
                      {Daylight, #absolute_lookup{is_dst = true}}]} ->
                    calendar:gregorian_seconds_to_datetime(
                        calendar:datetime_to_gregorian_seconds(Local) + Standard - Daylight);
                _ -> Local
            end;
        {ok, #absolute_lookup{date = Local}} -> Local;
        Error -> Error
    end.

local_to_utc(Date, Zone) ->
    case local_infos(Date, Zone) of
        {ok, [{Stamp, _}]} -> datetime(Stamp);
        {ok, Infos} -> [datetime(Stamp) || {Stamp, _} <- Infos];
        skipped -> time_not_exists;
        Error -> Error
    end.

tz_name(Date, Zone) ->
    case local_infos(Date, Zone) of
        {ok, [{_, Info}]} -> name(Info);
        {ok, [{_, Standard}, {_, Daylight}]} -> {name(Standard), name(Daylight)};
        skipped -> unable_to_detect;
        Error -> Error
    end.

tz_shift(Date, Zone) ->
    case local_infos(Date, Zone) of
        {ok, [{_, Info}]} -> shift(Info);
        {ok, [{_, Standard}, {_, Daylight}]} -> {shift(Standard), shift(Daylight)};
        skipped -> unable_to_detect;
        Error -> Error
    end.

dst(Date, Zone) ->
    case local_infos(Date, Zone) of
        {ok, [{_, #absolute_lookup{is_dst = true}}]} -> is_in_dst;
        {ok, [_]} -> is_not_in_dst;
        {ok, [_, _]} -> ambiguous_time;
        skipped -> time_not_exists;
        Error -> Error
    end.

absolute(Date, Zone) ->
    with_zone(Zone, fun(Tz) -> elocaltime:absolute_lookup(Date, Tz) end).

local_infos(Date, Zone) ->
    with_zone(Zone, fun(Tz) ->
        case elocaltime:civil_lookup(Date, Tz) of
            {ok, #civil_lookup{civil_kind = unique, pre = Stamp}} ->
                infos([Stamp], Tz);
            {ok, #civil_lookup{civil_kind = repeated, pre = Pre, post = Post}} ->
                infos([Pre, Post], Tz);
            {ok, #civil_lookup{civil_kind = skipped}} -> skipped;
            Error -> Error
        end
    end).

infos(Stamps, Zone) ->
    Pairs = [begin
        {ok, Info} = elocaltime:absolute_lookup(Stamp, Zone),
        {Stamp, Info}
    end || Stamp <- Stamps],
    %% qdate expects standard first and daylight second. CCTZ's pre/post
    %% ordering describes transition sides, not the DST flag. For political
    %% overlaps with identical DST flags, prefer the later instant first.
    {ok, lists:sort(fun({A, IA}, {B, IB}) ->
        {IA#absolute_lookup.is_dst, -A} < {IB#absolute_lookup.is_dst, -B}
    end, Pairs)}.

with_zone(Zone, Fun) ->
    Name = localtime:get_timezone(Zone),
    case safe_name(Name) of
        false -> {error, unknown_tz};
        true ->
            ok = ensure_started(),
            case Fun(list_to_binary(Name)) of
                {error, <<"unknown timezone">>} -> {error, unknown_tz};
                Result -> Result
            end
    end.

safe_name([]) -> false;
safe_name([$/ | _]) -> false;
safe_name(Name) ->
    not lists:member($., Name) andalso
    lists:all(fun(C) ->
        (C >= $A andalso C =< $Z) orelse (C >= $a andalso C =< $z) orelse
        (C >= $0 andalso C =< $9) orelse lists:member(C, "_/-+")
    end, Name).

ensure_started() ->
    case whereis(elocaltime_timezone) of
        undefined ->
            case application:ensure_all_started(elocaltime) of
                {ok, _} -> ok;
                {error, Reason} -> erlang:error({timezone_provider_unavailable, Reason})
            end;
        _ -> ok
    end.

name(#absolute_lookup{tz_abbreviation = Abbr}) ->
    Text = binary_to_list(Abbr),
    {Text, Text}.

shift(#absolute_lookup{offset = Offset}) when Offset rem 60 =:= 0 ->
    Sign = case Offset < 0 of true -> '-'; false -> '+' end,
    {Sign, abs(Offset) div 3600, (abs(Offset) rem 3600) div 60};
shift(#absolute_lookup{}) ->
    {error, subminute_offset}.

datetime(Stamp) ->
    calendar:gregorian_seconds_to_datetime(Stamp + 62167219200).
