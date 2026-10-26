%% @author  Dmitry S. Melnikov (dmitryme@gmail.com)
%% @copyright 2010 Dmitry S. Melnikov

-module(localtime).

-author("Dmitry Melnikov <dmitryme@gmail.com>").

-export(
  [
     utc_to_local/2
     ,local_to_utc/2
     ,local_to_local/3
     ,local_to_local_dst/3
     ,tz_name/2
     ,tz_shift/2
     ,tz_shift/3
     ,get_timezone/1
     ,list_timezones/0
     ,adjust_datetime/2
     ,fmt_shift/1
  ]).

% utc_to_local(UtcDateTime, Timezone) -> LocalDateTime | [LocalDateTime, DstLocalDateTime] | {error, ErrDescr}
%  UtcDateTime = DateTime()
%  Timezone = String()
%  LocalDateTime = DateTime()
%  DstLocalDateTime = DateTime()
%  ErrDescr = atom(), unknown_tz
utc_to_local(UtcDateTime, Timezone) ->
   localtime_os:utc_to_local(UtcDateTime, Timezone).

% local_to_utc(LocalDateTime, Timezone) -> UtcDateTime | [UtcDateTime, DstUtcDateTime] | time_not_exists | {error, ErrDescr}
%  LocalDateTime = DateTime()
%  Timezone = String()
%  UtcDateTime = DateTime()
%  DstUtcDateTime = DateTime()
%  ErrDescr = atom(), unknown_tz
local_to_utc(LocalDateTime, Timezone) ->
   localtime_os:local_to_utc(LocalDateTime, Timezone).

% local_to_local(LocalDateTime, TimezoneFrom, TimezoneTo) -> LocalDateTime | ambiguous | time_not_exists | {error, ErrDescr}
%  LocalDateTime = DateTime()
%  TimezoneFrom = String()
%  TimezoneTo = String()
%  ErrDescr = atom(), unknown_tz
local_to_local(LocalDateTime, TimezoneFrom, TimezoneTo) ->
   case local_to_utc(LocalDateTime, TimezoneFrom) of
      UtcDateTime = {{_,_,_},{_,_,_}} ->
         LocalDateTime2 = utc_to_local(UtcDateTime, TimezoneTo);
      [UtcDateTime, {{_,_,_},{_,_,_}}] ->
         LocalDateTime2 = utc_to_local(UtcDateTime, TimezoneTo);
      Res ->
         LocalDateTime2 = Res
   end,
   case LocalDateTime2 of
      [DateTimeToReturn, {{_,_,_},{_,_,_}}] ->
         DateTimeToReturn;
      Other ->
         Other
   end.

% local_to_local_dst(LocalDateTime, TimezoneFrom, TimezoneTo) -> LocalDateTime | ambiguous | time_not_exists | {error, ErrDescr}
%  LocalDateTime = DateTime()
%  TimezoneFrom = String()
%  TimezoneTo = String()
%  ErrDescr = atom(), unknown_tz
local_to_local_dst(LocalDateTime, TimezoneFrom, TimezoneTo) ->
   case local_to_utc(LocalDateTime, TimezoneFrom) of
      UtcDateTime = {{_,_,_},{_,_,_}} ->
         LocalDateTime2 = localtime_os:utc_to_local_dst(UtcDateTime, TimezoneTo);
      [{{_,_,_},{_,_,_}}, UtcDateTime] ->
         LocalDateTime2 = localtime_os:utc_to_local_dst(UtcDateTime, TimezoneTo);
      Res ->
         LocalDateTime2 = Res
   end,
   case LocalDateTime2 of
      [{{_,_,_},{_,_,_}}, DateTimeToReturn] ->
         DateTimeToReturn;
      Other ->
         Other
   end.

% tz_name(DateTime(), Timezone) -> {Abbr, Name} | {{StdAbbr, StdName}, {DstAbbr, DstName}} | unable_to_detect | {error, ErrDesc}
%  Timezone = String()
%  Abbr = String()
%  Name = String()
%  StdAbbr = String()
%  StdName = String()
%  DstAbbr = String()
%  DstName = String()
%  ErrDesc = atom(), unknown_tz
tz_name(_UtcDateTime, "UTC") ->
   {"UTC", "UTC"};
tz_name(LocalDateTime, Timezone) ->
   localtime_os:tz_name(LocalDateTime, Timezone).

% tz_shift(LocalDateTime, Timezone) ->  Shift | {Shift, DstSift} | unable_to_detect | {error, ErrDesc}
%  returns time shift from GMT
%  LocalDateTime = DateTime()
%  Timezone = String()
%  Shift = DstShift = {Sign, Hours, Minutes}
%  Sign = term(), '+', '-'
%  Hours = Minutes = Integer(),
%  {Shift, DstShift} - returns, when shift is ambiguous
%  ErrDesc = atom(), unknown_tz
tz_shift(_UtcDateTime, "UTC") ->
   0;
tz_shift(LocalDateTime, Timezone) ->
   localtime_os:tz_shift(LocalDateTime, Timezone).

% the same as tz_shift/2, but calculates time difference between two local timezones
tz_shift(LocalDateTime, TimezoneFrom, TimezoneTo) ->
   F = fun() ->
      FromShift = fmt_shift(tz_shift(LocalDateTime, TimezoneFrom)),
      DateTimeTo = localtime:local_to_local(LocalDateTime, TimezoneFrom, TimezoneTo),
      ToShift = fmt_shift(tz_shift(DateTimeTo, TimezoneTo)),
      fmt_min(ToShift-FromShift)
   end,
   try F()
   catch
      _:Err ->
         Err
   end.

adjust_datetime(DateTime, Minutes) ->
   Seconds = calendar:datetime_to_gregorian_seconds(DateTime) + Minutes * 60,
   calendar:gregorian_seconds_to_datetime(Seconds).

get_timezone(TimeZone) ->
    get_timezone_inner(TimeZone).

list_timezones() ->
    tz_index:all().

% =======================================================================
% privates
% =======================================================================

fmt_min(Shift) when Shift < 0 ->
   {'-', abs(Shift) div 60, abs(Shift) rem 60};
fmt_min(Shift) ->
   {'+', Shift div 60, Shift rem 60}.

fmt_shift({'+', H, M}) ->
   H * 60 + M;
fmt_shift({'-', H, M}) ->
   -(H * 60 + M);
fmt_shift(0) ->
   0;
fmt_shift(Any) ->
   throw(Any).

tr_char(String, From, To) ->
   case string:chr(String, From) of
      0 -> String; % Optimize for String does not contain From.
      _ -> tr_char(String, From, To, [])
   end.
tr_char([], _From, _To, Acc) ->
   lists:reverse(Acc);
tr_char([H|T], From, To, Acc) ->
   case H of
      From -> tr_char(T, From, To, [To|Acc]);
      _ -> tr_char(T, From, To, [H|Acc])
   end.

-define(SPACE_CHAR, 32).
get_timezone_inner(TimeZone) when is_binary(TimeZone) ->
    get_timezone_inner(erlang:binary_to_list(TimeZone));
%% Keep qdate's familiar short names stable. The old generated index picked
%% the first region with that abbreviation in the 2015 snapshot; those regions
%% can have different historical rules or change their clocks independently.
get_timezone_inner("PST") -> "America/Los_Angeles";
get_timezone_inner("PDT") -> "America/Los_Angeles";
get_timezone_inner("MST") -> "America/Denver";
get_timezone_inner("MDT") -> "America/Denver";
get_timezone_inner("CST") -> "America/Chicago";
get_timezone_inner("CDT") -> "America/Chicago";
get_timezone_inner("EST") -> "America/New_York";
get_timezone_inner("EDT") -> "America/New_York";
get_timezone_inner("CET") -> "Europe/Paris";
get_timezone_inner("CEST") -> "Europe/Paris";
%% qdate's unqualified GMT+N means east of UTC. Explicit Etc/GMT+N keeps
%% IANA's POSIX convention, so canonical names are not rewritten.
get_timezone_inner("GMT+" ++ Hours = Zone) ->
    legacy_gmt_zone(Hours, "Etc/GMT-", Zone);
get_timezone_inner("GMT-" ++ Hours = Zone) ->
    legacy_gmt_zone(Hours, "Etc/GMT+", Zone);
get_timezone_inner(TimeZone) when is_list(TimeZone) ->
   TimeZoneNoSpaces = tr_char(TimeZone, ?SPACE_CHAR, $_),
   case tz_index:lookup(TimeZoneNoSpaces) of
      error ->
        TimeZoneNoSpaces;
      [TZName | _] ->
        TZName
   end;
get_timezone_inner(TZ) ->
    throw({error, "Timezone should be string/binary", {provided_timezone, TZ}}).

legacy_gmt_zone([], _Prefix, Original) -> Original;
legacy_gmt_zone(Hours, Prefix, Original) ->
    case lists:all(fun(C) -> C >= $0 andalso C =< $9 end, Hours) of
        true -> Prefix ++ Hours;
        false -> Original
    end.

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

tr_char_test() ->
   ?assertEqual("ABCDE", tr_char("ABCDE", ?SPACE_CHAR, $_)),
   ?assertEqual("AB_DE", tr_char("AB DE", ?SPACE_CHAR, $_)),
   ?assertEqual("A_C_E", tr_char("A C E", ?SPACE_CHAR, $_)).

tz_name_test() ->
   ?assertEqual({"CET", "CET"}, tz_name({{2008,12,10},{15,30,0}}, "Europe/Amsterdam")),
   %% IANA uses numeric abbreviations for Iran. Iran observed DST in 2020.
   ?assertEqual({"+0330", "+0330"}, tz_name({{2008,12,10},{15,30,0}}, "Asia/Tehran")),
   ?assertEqual({"+0430", "+0430"}, tz_name({{2020,5,4},{15,30,0}}, "Asia/Tehran")),
   ?assertEqual({"+0330", "+0330"}, tz_name({{2008,12,10},{15,30,0}}, "Iran")),
   ?assertEqual({"+0430", "+0430"}, tz_name({{2020,5,4},{15,30,0}}, "Iran")).

get_timezone_test() ->
   ?assertEqual("America/Los_Angeles", get_timezone("America/Los Angeles")).

tz_shift_test() ->
   ?assertEqual({'+',3,0}, tz_shift({{2014,1,1},{12,0,0}}, "America/Los_Angeles", "America/New_York")).

-endif. % TEST
