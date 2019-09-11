import std.algorithm;
import std.array;
import std.csv;
import std.datetime;
import std.exception;
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
            auto roundedDuration = dur!"minutes"(duration.total!"minutes");
            writefln("'%s' for %s (uuid='%s')", info[task.uuid]["description"].str, roundedDuration, task.uuid);
        }
    }
}

void main()
{
    showActiveTasks();
}
