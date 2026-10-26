-module(localtime_os_tests).
-include_lib("eunit/include/eunit.hrl").

utc_is_unique_test() ->
    %% A repeated local clock time still has exactly one result for each UTC instant.
    Local = {{2026,11,1},{1,30,0}},
    Standard = {{2026,11,1},{9,30,0}},
    Daylight = {{2026,11,1},{8,30,0}},
    ?assertEqual(Local, localtime:utc_to_local(Standard, "America/Los_Angeles")),
    ?assertEqual(Local, localtime:utc_to_local(Daylight, "America/Los_Angeles")),
    ?assertEqual([Standard, Daylight], localtime:local_to_utc(Local, "America/Los_Angeles")),
    ?assertEqual(Standard, localtime:local_to_local(Local, "America/Los_Angeles", "UTC")),
    ?assertEqual(Daylight, localtime:local_to_local_dst(Local, "America/Los_Angeles", "UTC")).

fractional_transition_test() ->
    Local = {{2026,4,5},{1,45,0}},
    ?assertEqual([{{2026,4,4},{15,15,0}}, {{2026,4,4},{14,45,0}}],
                 localtime:local_to_utc(Local, "Australia/Lord_Howe")),
    ?assertEqual(ambiguous_time, localtime_dst:check(Local, "Australia/Lord_Howe")).

calendar_range_test_() ->
    [?_assertEqual({{Year,1,15},{12,0,0}},
                   localtime:utc_to_local({{Year,1,15},{12,0,0}}, "Etc/UTC"))
     || Year <- [1, 1900, 1960, 1970, 2038, 2263, 2300, 9999]].

unknown_zone_test_() ->
    Date = {{2026,12,1},{12,0,0}},
    [?_assertEqual({error, unknown_tz}, localtime:utc_to_local(Date, Zone))
     || Zone <- ["Unknown/Zone", "../etc/passwd", "/etc/passwd", "file:/etc/passwd", ""]].

legacy_alias_test_() ->
    Date = {{1970,1,1},{0,0,0}},
    [?_assertEqual(21600, calendar:datetime_to_gregorian_seconds(
                    localtime:local_to_utc(Date, "CST")) - 62167219200),
     ?_assertEqual({{1970,1,1},{1,0,0}}, localtime:utc_to_local(Date, "CET")),
     ?_assertEqual({{1970,1,1},{1,0,0}}, localtime:utc_to_local(Date, "GMT+1")),
     ?_assertEqual({{1969,12,31},{23,0,0}}, localtime:utc_to_local(Date, "GMT-1")),
     ?_assertEqual({{1969,12,31},{23,0,0}}, localtime:utc_to_local(Date, "Etc/GMT+1")),
     ?_assertEqual({{1970,1,1},{1,0,0}}, localtime:utc_to_local(Date, "Etc/GMT-1")),
     ?_assertEqual("America/Los_Angeles", localtime:get_timezone("PST")),
     ?_assertEqual("America/Chicago", localtime:get_timezone(<<"CDT">>))].

qdate_target_preference_test() ->
    Date = {{2013,11,3},{6,0,0}},
    ?assertEqual({{2013,11,3},{1,0,0}}, localtime:utc_to_local(Date, "America/New_York")),
    ?assertEqual({{2013,11,3},{1,0,0}}, localtime:local_to_local(Date, "GMT", "America/New_York")),
    ?assertEqual({{2013,11,3},{2,0,0}}, localtime:local_to_local_dst(Date, "GMT", "America/New_York")).
