import std.algorithm;
import std.array;
import std.conv;
import std.csv;
import std.datetime;
import std.exception;
import std.format;
import std.json;
import std.process;
import std.range;
import std.stdio;
import std.string;
import common;

alias TaskInformation = JSONValue;

ActiveTaskEntry[] retrieveActiveTasks()
{
    try
    {
        typeof(return) entries;
        auto f = File(activeFilename, "r");
        scope(exit) f.close();

        foreach (entry; f.byLine.joiner("\n").csvReader!ActiveTaskEntry)
        {
            entries ~= entry;
        }

        return entries[1..$];
    }
    catch(ErrnoException e)
    {
        return [];
    }
}

WorkInterval[] retrieveWorkIntervals()
{
    try
    {
        WorkIntervalEntry[] entries;
        auto f = File(intervalsFilename, "r");
        scope(exit) f.close();

        foreach (entry; f.byLine.joiner("\n").csvReader!WorkIntervalEntry)
        {
            entries ~= entry;
        }

        typeof(return) intervals;
        foreach (entry ; entries[1..$])
        {
            intervals ~= WorkInterval(entry.uuid,
                SysTime.fromISOExtString(entry.startDate),
                SysTime.fromISOExtString(entry.endDate));
        }
        return intervals;
    }
    catch(ErrnoException e)
    {
        return [];
    }
}

TaskInformation[string] queryTaskInformation(T)(T[] tasks)
in(tasks.length > 0, "there should be tasks to query")
{
    typeof(return) info;
    auto args = ["task", "export"] ~ tasks.map!(a => a.uuid).array;
    auto p = execute(args);

    foreach (task; p.output.parseJSON.array)
    {
        info[task["uuid"].str] = task;
    }
    return info;
}

bool isScalar(JSONValue v)
{
    return (v.type == JSONType.string) ||
           (v.type == JSONType.integer) ||
           (v.type == JSONType.float_) ||
           (v.type == JSONType.true_) ||
           (v.type == JSONType.false_);
}

string asString(JSONValue v)
{
    switch(v.type)
    {
        case JSONType.string: return format!`"%s"`(v.str.tr(`"`, `""`));
        case JSONType.integer: return to!string(v.integer);
        case JSONType.float_: return to!string(v.floating);
        case JSONType.true_: return to!string(true);
        case JSONType.false_: return to!string(false);
        default: throw new Exception(format!"%s is not scalar"(v));
    }
}

string[string][] flattenArrays(TaskInformation info)
{
    typeof(return) flattened;

    string[string] toPreserve;
    foreach(key, value; info.object)
    {
        if (value.isScalar)
            toPreserve[key] = value.asString;
    }

    if ("tags" in info.object)
    {
        string[] tags;
        foreach (tag; info.object["tags"].array)
            tags ~= tag.asString;

        foreach (tag; tags)
        {
            auto element = toPreserve.dup;
            element["tag"] = tag;
            flattened ~= element;
        }
    }
    else
        flattened ~= toPreserve;

    return flattened;
}

string generateExportCSV(WorkInterval[] intervals, string[string][][string] infos)
{
    static immutable string NA = `"NA"`;

    // List all keys.
    bool[string] keys;
    foreach (uuid, info; infos)
    {
        foreach (i; info)
        {
            foreach (key; i.keys)
            {
                if (key !in keys)
                    keys[key] = true;
            }
        }
    }

    // Define a CSV key order.
    auto sortedKeys = ["interval_start", "interval_end", "uuid", "project", "tag", "description"];
    foreach (key; keys.keys)
    {
        if (!sortedKeys.canFind(key))
            sortedKeys ~= key;
    }

    // Generate rows.
    string[] rows;
    rows ~= sortedKeys.join(",");

    foreach (interval; intervals)
    {
        foreach (info; infos[interval.uuid])
        {
            string row = format!"%s,%s,%s"(interval.startDate, interval.endDate, interval.uuid);

            foreach(key; sortedKeys[3..$])
            {
                string value = (key in info) ? info[key] : NA;
                row ~= "," ~ value;
            }

            rows ~= row;
        }
    }

    return rows.join("\n");
}

Duration roundMinuteOrSecond(Duration duration)
{
    auto rounded = dur!"minutes"(duration.total!"minutes");
    if (rounded.toString == "0 hnsecs")
    {
        rounded = dur!"seconds"(duration.total!"seconds");
    }
    return rounded;
}

SysTime roundDay(SysTime time)
{
    return SysTime(DateTime(time.year(), time.month(), time.day()));
}

SysTime roundMonth(SysTime time)
{
    return SysTime(DateTime(time.year(), time.month(), 1));
}

void showActiveTasks()
{
    auto tasks = retrieveActiveTasks;
    if (tasks.empty)
        writeln("No active task.");
    else
    {
        auto info = queryTaskInformation(tasks);
        foreach (task; tasks)
        {
            auto duration = Clock.currTime - SysTime.fromISOExtString(task.startDate);
            writefln("'%s' for %s (uuid='%s')", info[task.uuid]["description"].str, duration.roundMinuteOrSecond, task.uuid);
        }
    }
}

SysTime fromAnyDateTimeString(string s)
{
    try { return SysTime.fromISOExtString(s); } catch(std.datetime.date.DateTimeException e) {}
    try { return SysTime.fromISOString(s); } catch(std.datetime.date.DateTimeException e) {}
    try { return SysTime(Date.fromISOExtString(s)); } catch(std.datetime.date.DateTimeException e) {}
    try { return SysTime(Date.fromISOString(s)); } catch(std.datetime.date.DateTimeException e) {}
    try { return SysTime.fromSimpleString(s); } catch(std.datetime.date.DateTimeException e) {}
    try { SysTime.fromUnixTime(to!long(s)); } catch(Exception e) {}

    immutable string error = format!"Cannot convert '%s' to a date.\n"(s) ~
        "Try giving an ISO representation such as 'YYYY-MM-DD', 'YYYYMMDD', 'YYYY-MM-DDTHH:MM:SS' or 'YYYYMMDDTHHMMSS'.";
    throw new Exception(error);
}

int main(string[] args)
{
    static immutable usage = `Usage:
  logwarrior [show]
  logwarrior export [day | week | month | start_date | start_date..end_date]
  logwarrior --help`;

    // Parse command-line
    if (args.canFind("--help"))
    {
        writeln(usage);
        return 0;
    }

    string command = "show";
    if (args.length > 1)
        command = args[1];
    string[] commandArgs;
    if (args.length > 2)
        commandArgs = args[2..$];

    try
    {
        switch (command)
        {
            case "show":
                enforce(commandArgs.length == 0, "The 'show' command has no arguments.");
                showActiveTasks();
                break;
            case "export":
                enforce(commandArgs.length <= 1, "The 'export' command expect 0 or 1 argument.");
                auto startDate = Clock.currTime;
                auto endDate = startDate;

                if (commandArgs.empty)
                    commandArgs ~= "day";

                auto intervalString = commandArgs[0];
                switch(intervalString)
                {
                    case "day":
                        startDate = startDate.roundDay;
                        break;
                    case "week":
                        startDate -= dur!"days"(daysToDayOfWeek(DayOfWeek.mon, startDate.dayOfWeek));
                        startDate = startDate.roundDay;
                        break;
                    case "month":
                        startDate = startDate.roundMonth;
                        break;
                    default:
                        auto startDateString = "";
                        auto endDateString = endDate.toISOExtString;
                        if (intervalString.canFind(".."))
                        {
                            auto s = intervalString.split("..");
                            startDateString = s[0];
                            endDateString = s[1];
                        }
                        else
                            startDateString = intervalString;

                        startDate = fromAnyDateTimeString(startDateString);
                        endDate = fromAnyDateTimeString(endDateString);
                }
                auto intervals = retrieveWorkIntervals();
                auto selectedIntervals = intervals.filter!(a => (a.startDate >= startDate &&
                                                           a.endDate <= endDate)).array;
                if (selectedIntervals.empty)
                {
                    writeln("interval_start,interval_end,uuid");
                    break;
                }

                auto infos = queryTaskInformation(selectedIntervals);
                string[string][][string] flattenedInfos;
                foreach (uuid, info; infos)
                {
                    flattenedInfos[uuid] = flattenArrays(info);
                }

                auto exportString = generateExportCSV(selectedIntervals, flattenedInfos);
                writeln(exportString);
                break;
            default:
                enforce(false, format!"Unknown '%s' command."(command));
        }
    }
    catch(Exception e)
    {
        writefln("%s\nRun 'logwarrior --help' for usage.", e.msg);
        return 1;
    }

    return 0;
}
