using System;
using System.Diagnostics;
using System.Linq;
using Vars.Deducer;

while (Hear2() is ("deduce", _))
{
    Deduce();
    Say("@YIELD");
}

static void Deduce()
{
    Log("Outlines");

    var outlines = Outlines.Parse(Hear());
    foreach (var o in outlines.Items)
    {
        Log(o.ToString());
    }
    
    var rawTargets = Hear();
    Log("Targets");
    Log(rawTargets);
    
    var rawBlocks = Hear();
    Log("Blocks");
    Log(rawBlocks);
    
    var rawModes = Hear();
    Log("Modes");
    Log(rawModes);


    var proc = Process.Start(new ProcessStartInfo
    {
        FileName = "/home/jason/src/vars/deducer.sh",
        EnvironmentVariables = { ["VARS_PATH"] = "/home/jason/src/vars" },
        RedirectStandardInput = true,
    });
    
    proc.StandardInput.WriteLine("deduce");
    proc.StandardInput.WriteLine(string.Join(' ', outlines.Items.Select(o => o.ToString())));
    proc.StandardInput.WriteLine(rawTargets);
    proc.StandardInput.WriteLine(rawBlocks);
    proc.StandardInput.WriteLine(rawModes);
    
    Console.OpenStandardInput().CopyTo(proc.StandardInput.BaseStream);
    
    // Say("targets blah");
    // Say("fin");
}


static void Log(string msg)
    => Console.Error.WriteLine(msg);

static void Say(string line)
    => Console.WriteLine(line);

static string? Hear()
    => Console.ReadLine();

static (string?, string?)? Hear2()
    => Hear() is string line
        ? Split2(line)
        : null;
    
static (string?, string?) Split2(string str)
{
    var parts = str.Split(" ", 2, StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
    return (parts.ElementAtOrDefault(0), parts.ElementAtOrDefault(1));
}