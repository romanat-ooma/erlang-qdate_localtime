-module(localtime_canada_tests).

-include_lib("eunit/include/eunit.hrl").

%% Offset in minutes, winter name, final daylight name, permanent name.
zones() ->
    [{"America/Vancouver", -420, "PST", "PDT", "MST"}
    ,{"Canada/Pacific", -420, "PST", "PDT", "MST"}
    ,{"America/Edmonton", -360, "MST", "MDT", "CST"}
    ,{"Canada/Mountain", -360, "MST", "MDT", "CST"}
    ,{"America/Yellowknife", -360, "MST", "MDT", "CST"}
    ,{"America/Inuvik", -360, "MST", "MDT", "CST"}
    ,{"America/Winnipeg", -300, "CST", "CDT", "EST"}
    ,{"Canada/Central", -300, "CST", "CDT", "EST"}
    ,{"America/Rainy_River", -300, "CST", "CDT", "EST"}
    ].

canada_test_() ->
    [{Zone, zone_tests(Zone, Shift, WinterName, DaylightName, PermanentName)}
     || {Zone, Shift, WinterName, DaylightName, PermanentName} <- zones()].

zone_tests(Zone, Shift, WinterName, DaylightName, PermanentName) ->
    Winter = {{2026,1,15},{12,0,0}},
    Summer = {{2026,7,15},{12,0,0}},
    December = {{2026,12,1},{12,0,0}},
    FromLocal = {{2026,11,1},{2,0,0}},
    FromUtc = shift(FromLocal, -Shift),
    JustBeforeUtc = seconds(FromUtc, -1),
    JustBeforeLocal = {{2026,11,1},{1,59,59}},
    BeforeDayUtc = shift({{2026,10,31},{23,59,59}}, -Shift),
    NoOverlap = {{2026,11,1},{1,30,0}},
    NoGapNextSpring = {{2027,3,14},{2,30,0}},
    NoOverlapNextFall = {{2027,11,7},{1,30,0}},
    [?_assertEqual(shift(Winter, -(Shift-60)), localtime:local_to_utc(Winter, Zone))
    ,?_assertEqual(Winter, localtime:utc_to_local(shift(Winter, -(Shift-60)), Zone))
    ,?_assertEqual({WinterName, WinterName}, localtime:tz_name(Winter, Zone))
    ,?_assertEqual(is_not_in_dst, localtime_dst:check(Winter, Zone))
    ,?_assertEqual(Summer, localtime:utc_to_local(shift(Summer, -Shift), Zone))
    ,?_assertEqual({DaylightName, DaylightName}, localtime:tz_name(Summer, Zone))
    ,?_assertEqual(is_in_dst, localtime_dst:check(Summer, Zone))
    ,?_assertEqual({{2026,10,31},{23,59,59}}, localtime:utc_to_local(BeforeDayUtc, Zone))
    ,?_assertEqual(JustBeforeLocal, localtime:utc_to_local(JustBeforeUtc, Zone))
    ,?_assertEqual(JustBeforeUtc, localtime:local_to_utc(JustBeforeLocal, Zone))
    ,?_assertEqual({DaylightName, DaylightName}, localtime:tz_name(JustBeforeLocal, Zone))
    ,?_assertEqual(is_in_dst, localtime_dst:check(JustBeforeLocal, Zone))
    ,?_assertEqual(FromLocal, localtime:utc_to_local(FromUtc, Zone))
    ,?_assertEqual(FromUtc, localtime:local_to_utc(FromLocal, Zone))
    ,?_assertEqual({PermanentName, PermanentName}, localtime:tz_name(FromLocal, Zone))
    ,?_assertEqual(is_not_in_dst, localtime_dst:check(FromLocal, Zone))
    ,?_assertEqual({'-', abs(Shift) div 60, 0}, localtime:tz_shift(NoOverlap, Zone))
    ,?_assertEqual(shift(NoOverlap, -Shift), localtime:local_to_utc(NoOverlap, Zone))
    ,?_assertEqual(NoOverlap, localtime:utc_to_local(shift(NoOverlap, -Shift), Zone))
    ,?_assertEqual(is_in_dst, localtime_dst:check(NoOverlap, Zone))
    ,?_assertEqual(December, localtime:utc_to_local(shift(December, -Shift), Zone))
    ,?_assertEqual(shift(December, -Shift), localtime:local_to_utc(December, Zone))
    ,?_assertEqual({PermanentName, PermanentName}, localtime:tz_name(December, Zone))
    ,?_assertEqual(is_not_in_dst, localtime_dst:check(December, Zone))
    ,?_assertEqual(shift(NoGapNextSpring, -Shift), localtime:local_to_utc(NoGapNextSpring, Zone))
    ,?_assertEqual(NoGapNextSpring, localtime:utc_to_local(shift(NoGapNextSpring, -Shift), Zone))
    ,?_assertEqual(shift(NoOverlapNextFall, -Shift), localtime:local_to_utc(NoOverlapNextFall, Zone))
    ,?_assertEqual(NoOverlapNextFall, localtime:utc_to_local(shift(NoOverlapNextFall, -Shift), Zone))
    ,?_assertEqual(is_not_in_dst, localtime_dst:check(NoGapNextSpring, Zone))
    ,?_assertEqual(is_not_in_dst, localtime_dst:check(NoOverlapNextFall, Zone))
    ,?_assertEqual(December, localtime:utc_to_local(shift(December, -Shift), list_to_binary(Zone)))
    ,?_assertEqual(shift(December, -Shift), localtime:local_to_utc(December, list_to_binary(Zone)))
    ,?_assertEqual({'-', abs(Shift) div 60, 0}, localtime:tz_shift(December, Zone))
    ,?_assertEqual({'-', abs(Shift-60) div 60, 0}, localtime:tz_shift(Winter, Zone))
    ,?_assertEqual({PermanentName, PermanentName}, localtime:tz_name(December, list_to_binary(Zone)))
    ,?_assertEqual(is_not_in_dst, localtime_dst:check(December, list_to_binary(Zone)))
    ,?_assertEqual(shift(December, -Shift), localtime:local_to_local(December, Zone, "UTC"))
    ,?_assertEqual(shift(December, -Shift), localtime:local_to_local_dst(December, Zone, "UTC"))
    ,?_assertEqual(December, localtime:local_to_local(shift(December, -Shift), "UTC", Zone))
    ,?_assertEqual({'+', abs(Shift) div 60, 0}, localtime:tz_shift(December, Zone, "UTC"))

    ].

unaffected_zones_test_() ->
    Winter = {{2026,12,1},{20,0,0}},
    Summer = {{2027,7,1},{20,0,0}},
    [?_assertEqual({{2026,12,1},{12,0,0}}, localtime:utc_to_local(Winter, "America/Los_Angeles"))
    ,?_assertEqual({{2026,12,1},{13,0,0}}, localtime:utc_to_local(Winter, "America/Denver"))
    ,?_assertEqual({{2026,12,1},{14,0,0}}, localtime:utc_to_local(Winter, "America/Chicago"))
    ,?_assertEqual({{2027,7,1},{13,0,0}}, localtime:utc_to_local(Summer, "America/Los_Angeles"))
    ,?_assertEqual(time_not_exists,
                   localtime:local_to_utc({{2027,3,14},{2,30,0}}, "America/Los_Angeles"))
    ,?_assertMatch([{{2026,11,1},{_,30,0}}, {{2026,11,1},{_,30,0}}],
                   localtime:local_to_utc({{2026,11,1},{1,30,0}}, "America/Los_Angeles"))
    ,?_assertMatch([{{2025,11,2},{_,30,0}}, {{2025,11,2},{_,30,0}}],
                   localtime:local_to_utc({{2025,11,2},{1,30,0}}, "America/Vancouver"))
    ,?_assertEqual({error, unknown_tz}, localtime:utc_to_local(Winter, "Unknown/Zone"))
    ,?_assertEqual({error, unknown_tz}, localtime:local_to_utc(Winter, "Unknown/Zone"))
    ,?_assertEqual({error, unknown_tz}, localtime:tz_name(Winter, "Unknown/Zone"))
    ,?_assertEqual({error, unknown_tz}, localtime:tz_shift(Winter, "Unknown/Zone"))
    ,?_assertEqual({error, unknown_tz}, localtime_dst:check(Winter, "Unknown/Zone"))
    ].

shift(DateTime, Minutes) -> seconds(DateTime, Minutes * 60).

seconds(DateTime, Seconds) ->
    calendar:gregorian_seconds_to_datetime(calendar:datetime_to_gregorian_seconds(DateTime) + Seconds).
