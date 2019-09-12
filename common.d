import std.datetime;
import std.process;
import std.path;

struct ActiveTaskEntry
{
    string uuid;
    string startDate;
}

struct WorkIntervalEntry
{
    string uuid;
    string startDate;
    string endDate;
}

struct WorkInterval
{
    string uuid;
    SysTime startDate;
    SysTime endDate;
}

static immutable string ACTIVE_FILENAME = ".logw-active.csv";
static immutable string INTERVALS_FILENAME = "logw-intervals.csv";

string activeFilename()
{
    return environment.get("LOGWARRIOR_DIR", "~/.task").expandTilde ~ "/" ~ ACTIVE_FILENAME;
}

string intervalsFilename()
{
    return environment.get("LOGWARRIOR_DIR", "~/.task").expandTilde ~ "/" ~ INTERVALS_FILENAME;
}
