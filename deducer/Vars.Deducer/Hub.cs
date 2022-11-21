using Vars.Deducer;
using Vars.Deducer.Evaluators;
using Vars.Deducer.Model;

public static class Hub
{
    public static void Run(TextReader input, TextWriter output)
    {
        while (Hear2() is ("deduce", _))
        {
            Deduce();
            Say("@YIELD");
        }
        
        void Deduce()
        {
            Log("Outlines");
            var index = new OutlineIndex(HearMany().Select(Outline.Parse));
            foreach (var o in index)
            {
                Log(o.ToString());
            }

            Log("TargetBlocks");
            var rawTargetBlocks = HearMany();
            var targetBlocks = rawTargetBlocks.Select(b => new BlockTarget(b));
            Log(string.Join(' ', rawTargetBlocks));
            
            var modes = HearMany();
            Log("Modes");
            Log(string.Join(' ', modes));

            // var plan = Planner
            //     .Plan(index, targetBlocks)
            //     .ToFlatPlan();
            // Say(plan.ToString().ReplaceLineEndings(" "));
            
            Say("targets blah");


            var root = EvaluatorBuilder
                .WithContext<PerformContext>()
                .AddIOEvaluator(input, output)
                .Build();

            var prog = Planner
                .Plan(index, targetBlocks)
                .Deduce();

            var result = Engine<PerformContext>.Run(root, new PerformContext(Env.Empty, null!), prog);

            // var result = root.Eval(new PerformContext(Env.Empty, null!), prog).Run(root);
            
            //
            //
            
            Say("fin");

            // Log("");
            // Log("ORDERED");
            // foreach (var ol in ordered)
            // {
            //     Log(ol.ToString());
            // }
            

            // var proc = Process.Start(new ProcessStartInfo
            // {
            //     FileName = "/home/jason/src/vars/deducer.sh",
            //     EnvironmentVariables = { ["VARS_PATH"] = "/home/jason/src/vars" },
            //     RedirectStandardInput = true,
            // });
            //
            // proc.StandardInput.WriteLine("deduce");
            // proc.StandardInput.WriteLine(string.Join(' ', index.Select(o => o.ToString())));
            // proc.StandardInput.WriteLine(string.Join(' ', rawTargetBlocks));
            // proc.StandardInput.WriteLine();
            // proc.StandardInput.WriteLine(string.Join(' ', modes));
            //
            // Console.OpenStandardInput().CopyTo(proc.StandardInput.BaseStream);
            
            // Say("targets blah");
            // Say("fin");
        }
        
        void Log(string msg) {}
            // => Console.Error.WriteLine(msg);

        void Say(string line)
            => output.WriteLine(line);

        string? Hear()
            => input.ReadLine();

        string[] HearMany(char separator = ' ')
            => Hear()?.Split(separator, StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries) 
               ?? Array.Empty<string>();

        (string?, string?)? Hear2()
            => Hear() is string line
                ? Split2(line)
                : null;
            
        (string?, string?) Split2(string str)
        {
            var parts = str.Split(" ", 2, StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
            return (parts.ElementAtOrDefault(0), parts.ElementAtOrDefault(1));
        }
    }
}


// outlines can appear in more than one place in the tree
// we want to crawl to the bottom and only then enqueue the discovered block
//
//



namespace Vars.Deducer
{
    public record PerformContext(Env Env, RunContext Run)
        : IState<PerformContext, Env>, 
            IState<PerformContext, RunContext>
    {
        public static readonly PerformContext Empty = new(Env.Empty, null!);

        Env IState<PerformContext, Env>.Get() => Env;

        RunContext IState<PerformContext, RunContext>.Get() => Run;

        PerformContext IState<PerformContext, RunContext>.Put(RunContext run) => this with { Run = run };
        PerformContext IState<PerformContext, Env>.Put(Env env)  => this with { Env = env };

        Env IState<PerformContext, Env>.Zero => Env.Empty;
        Env IState<PerformContext, Env>.Combine(Env left, Env right)
        {
            throw new NotImplementedException();
        }

        RunContext IState<PerformContext, RunContext>.Zero => null!;
        RunContext IState<PerformContext, RunContext>.Combine(RunContext left, RunContext right)
        {
            throw new NotImplementedException();
        }
    }
}
