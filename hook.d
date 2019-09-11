import std.algorithm;
import std.csv;
import std.datetime;
import std.file;
import std.json;
import std.stdio;
import std.string;
import common;

static immutable string NOT_FOUND = "NOTFOUND";

string[string] parseProcessArgs(string[] args)
{
    string[string] ret;
    foreach (arg; args[1 .. $])
    {
        auto splitIndex = arg.indexOf(':');
        auto key = arg[0..splitIndex];
        auto value = arg[splitIndex+1..$];
        ret[key] = value;
    }
    return ret;
}

string retrieveTaskStartDate(string activeFilename, string uuid)
{
    auto f = File(activeFilename, "r");
    scope(exit) f.close();

    foreach (entry; f.byLine.joiner("\n").csvReader!ActiveEntry)
    {
        if (entry.uuid == uuid)
            return entry.startDate;
    }

    return NOT_FOUND;
}

void removeActiveTask(string activeFilename, string uuid)
{
    auto f = File(activeFilename, "r");
    string tmpFilename = tempDir ~ "/" ~ ACTIVE_FILENAME;
    auto tmp = File(tmpFilename, "w");

    foreach (entry; f.byLine.joiner("\n").csvReader!ActiveEntry)
    {
        if (entry.uuid != uuid)
            tmp.writefln("%s,%s", entry.uuid, entry.startDate);
    }

    f.close();
    tmp.close();

    tmpFilename.copy(activeFilename);
}

int main(string[] args)
{
    // Parse process arguments into an associative array.
    auto arguments = parseProcessArgs(args);

    // Read input lines (cf. taskwarrior hooks doc).
    string oldTask = stdin.readln();
    string newTask = stdin.readln();

    // Retrieve task uuid.
    string uuid = parseJSON(newTask)["uuid"].str;

    // Interval logs directory.
    string activeFilename = activeFilename();
    string dataFilename = intervalsFilename();

    // Create logwarrior data files if needed.
    if (!activeFilename.exists)
    {
        auto f = File(activeFilename, "w");
        f.writeln("task_uuid,start_date");
        f.close();
    }

    if (!dataFilename.exists)
    {
        auto f = File(dataFilename, "w");
        f.writeln("task_uuid,start_date,end_date");
        f.close();
    }

    // Finally, do something.
    if (arguments["api"] == "2") // Supported taskwarrior APIs
    {
        switch (arguments["command"])
        {
            default: break;
            case "start":
                // If the task is already marked as active by any chance, remove the previous mark.
                if (retrieveTaskStartDate(activeFilename, uuid) != NOT_FOUND)
                    removeActiveTask(activeFilename, uuid);

                // Mark the task as active.
                auto f = File(activeFilename, "a");
                f.writefln("%s,%s", uuid, Clock.currTime.toISOExtString);
                f.close();
                break;
            case "stop":
                // If the stopped task is not known as active, do nothing.
                auto startDate = retrieveTaskStartDate(activeFilename, uuid);
                if (startDate != NOT_FOUND)
                {
                    // Otherwise, log the work interval.
                    auto f = File(dataFilename, "a");
                    f.writefln("%s,%s,%s", uuid, startDate, Clock.currTime.toISOExtString);
                    f.close();

                    // And mark the task as no longer active.
                    removeActiveTask(activeFilename, uuid);
                }
                break;
        }
    }

    // Write the unmodified task on standard output (cf. taskwarrior hooks doc).
    write(newTask);

    return 0;
}
