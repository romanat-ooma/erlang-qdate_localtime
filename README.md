## NOTE

This is a fork of the excellent library,
[erlang_localtime](https://github.com/dmitryme/erlang_localtime). The purpose
of this fork is specifically for compatibility with
[qdate](https://github.com/choptastic/qdate).  The two are mostly compatible,
but have diverged slightly over the years.  The qdate tests will not pass if the
original `erlang_localtime dependency` is used due to some subtle differences
to attempt to make qdate a little bit smarter.

#### OS tzdata prototype (2.0.0-prototype)

This branch evaluates replacing the recurring timezone snapshot with
[`elocaltime`](https://github.com/silviucpp/elocaltime) and Google CCTZ. Conversion
rules come from the runtime machine's `/usr/share/zoneinfo`, or `TZDIR` set before
starting the Erlang VM. Containers use their own files. Install and record a
current OS `tzdata` package; this library does not download timezone updates.

**This is a viability prototype, not a release dependency.** The pinned upstream
`elocaltime` 1.5.1 needs the signed-timestamp/clock-resolution correction in
`test/elocaltime-timestamp-range.patch`. CI applies that patch to the pinned
upstream source. A production version must publish that native fix and update
the dependency ref before the adapter can be released. The patch avoids rejected
pre-1970 timestamps and incorrect years after 2262.

The existing `localtime` entry points and return shapes remain available. UTC
instants now always produce one local datetime. Local gaps return
`time_not_exists`; overlaps return standard first and daylight second, preserving
qdate's selection contract. Transition sides are classified by their actual DST
flags rather than assuming CCTZ's `pre` and `post` mean standard and daylight.
Overlaps with equal DST flags prefer the later instant first. Explicit tuples
passed to `localtime_dst:check/2` still evaluate the supplied recurring rule.

OS rules also correct historical behavior outside Canada, so this changes more
than the targeted 1.2.3 fix. Abbreviations follow IANA (including numeric names);
`tz_shift/2` returns `{error, subminute_offset}` for historical offsets that its
minute-based interface cannot represent. Conversion itself retains seconds.
The legacy abbreviation index is retained for compatibility; prefer canonical
IANA names for new configuration. Unknown zones do not fall back to old rules.

Updating files or restarting just the `elocaltime` application does not clear
CCTZ's cache. Roll out tzdata with a **full Erlang VM restart**.

The regression workflow builds the native dependency on OTP 26, 27 and 28, runs
393 EUnit cases and nine native integrity cases, and compares Canadian results
against 4,185 vectors from the checksum-pinned official IANA 2026e archive. The
archive is compiled for CI only; it is not bundled as the production database.
For manual tests, build the patched native dependency first and include its
parent directory in `ERL_LIBS`:

```sh
ERL_LIBS=/path/to/native-apps TZDIR=/path/to/zoneinfo bash test/run.sh
ERL_LIBS=/path/to/native-apps TZDIR=/path/to/zoneinfo \
  python3 test/check_iana.py /path/to/tzdata2026e.tar.gz
```

#### Public exports

* `utc_to_local(DateTime, Timezone)` - converts UTC time to local according to specified Timezone
* `local_to_utc(DateTime, Timezone)` - converts local time to UTC
* `local_to_local(DateTime, TimezoneFrom, TimezoneTo)` - converts local time to local
* `tz_name(DateTime, Timezone)` - returns a timezone name (E.g. MSK, MSD, etc)
* `tz_shift(DateTime, Timezone)` - returns time difference between local datetime and GMT
* `tz_shift(DateTime, TimezoneFrom, TimezoneTo)` - returns time difference between local datetime and required timezone
Where
DateTime = {date(), time()}
TimeZone(To, From) = String(). E.g. “Europe/Moscow”, “America/NewYork”. Or abbreviations "MSK", "MSD", etc. Note:
abbreviation is just used to find appropriate timezone name. If you want to convert "MSK" -> "PDT", but source timezone
is not in daylight saving, it will be corrected by library and "MSK" -> "PST" conversion will be made.

#### Examples of usage

With OS tzdata 2026e, UTC conversion uses the rules at the event date:

```erlang
localtime:utc_to_local({{2026,1,15},{20,0,0}}, "America/Vancouver").
%% {{2026,1,15},{12,0,0}}
localtime:utc_to_local({{2026,12,1},{20,0,0}}, "America/Vancouver").
%% {{2026,12,1},{13,0,0}}
```

Local overlaps and gaps keep qdate's existing return conventions:

```erlang
localtime:local_to_utc({{2026,11,1},{1,30,0}}, "America/Los_Angeles").
%% [{{2026,11,1},{9,30,0}}, {{2026,11,1},{8,30,0}}]
localtime:local_to_utc({{2027,3,14},{2,30,0}}, "America/Los_Angeles").
%% time_not_exists
```
