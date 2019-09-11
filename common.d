import std.process;
import std.path;

struct ActiveEntry
{
    string uuid;
    string startDate;
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
