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
import common;

alias TaskInformation = JSONValue;

ActiveEntry[] retrieveActiveTasks()
{
    try
    {
        typeof(return) entries;
        auto f = File(activeFilename, "r");
        scope(exit) f.close();

        foreach (entry; f.byLine.joiner("\n").csvReader!ActiveEntry)
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

TaskInformation[string] queryTaskInformation(ActiveEntry[] tasks)
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
                auto startDate = Clock.currTime;
                auto endDate = startDate;

                if (commandArgs.length > 0)
                {
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
                }
                writeln(startDate);
                writeln(endDate);
                enforce(false, "The 'export' command is not implemented yet.");
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
