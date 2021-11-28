using System;
using System.Diagnostics;
using System.Linq;
using Vars.Deducer;
using Vars.Deducer.Model;

while (Hear2() is ("deduce", _))
{
    Deduce();
    Say("@YIELD");
}

static void Deduce()
{
    Log("Outlines");
    var index = new OutlineIndex(HearMany().Select(Outline.Parse));
    foreach (var o in index)
    {
        Log(o.ToString());
    }

    Log("TargetBlocks");
    var rawTargetBlocks = HearMany();
    Log(string.Join(' ', rawTargetBlocks));
    
    var modes = HearMany();
    Log("Modes");
    Log(string.Join(' ', modes));

    var ordered = Deducer.Deduce(index, rawTargetBlocks.Select(b => new BlockTarget(b)));

    Log("");
    Log("ORDERED");
    foreach (var ol in ordered)
    {
        Log(ol.ToString());
    }

    var proc = Process.Start(new ProcessStartInfo
    {
        FileName = "/home/jason/src/vars/deducer.sh",
        EnvironmentVariables = { ["VARS_PATH"] = "/home/jason/src/vars" },
        RedirectStandardInput = true,
    });
    
    proc.StandardInput.WriteLine("deduce");
    proc.StandardInput.WriteLine(string.Join(' ', index.Select(o => o.ToString())));
    proc.StandardInput.WriteLine(string.Join(' ', rawTargetBlocks));
    proc.StandardInput.WriteLine();
    proc.StandardInput.WriteLine(string.Join(' ', modes));
    
    Console.OpenStandardInput().CopyTo(proc.StandardInput.BaseStream);
    
    // Say("targets blah");
    // Say("fin");
}

// outlines can appear in more than one place in the tree
// we want to crawl to the bottom and only then enqueue the discovered block
//
//


static void Log(string msg)
    => Console.Error.WriteLine(msg);

static void Say(string line)
    => Console.WriteLine(line);

static string? Hear()
    => Console.ReadLine();

static string[] HearMany(char separator = ' ')
    => Hear()?.Split(separator, StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries) 
       ?? Array.Empty<string>();

static (string?, string?)? Hear2()
    => Hear() is string line
        ? Split2(line)
        : null;
    
static (string?, string?) Split2(string str)
{
    var parts = str.Split(" ", 2, StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
    return (parts.ElementAtOrDefault(0), parts.ElementAtOrDefault(1));
}