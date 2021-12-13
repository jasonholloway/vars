using System;
using System.Collections.Immutable;
using System.Linq;
using Vars.Deducer.Model;

namespace Vars.Deducer
{

    public class IO<T>
    {
        
    }
    
    
    
    public static class PlanExtensions2
    {
        public static Env Perform(this Plan2 plan, IRunner runner, Env? env = null)
            => plan
                .RoundUpInputs()
                .Perform(runner, env ?? new Env(), 0);
        
        static Env Perform(this Lattice<(ImmutableHashSet<Var>, PlanNode)> plan, IRunner runner, Env env, int depth)
        {
            if (plan.Node is var (allInputs, node))
            {
                switch (node)
                {
                    case PlanNode.Block(Outline(_, _, var inputs, var outputs, var flags) outline):
                        if (depth > 0 && outputs.All(v => env[v.Name].Value != null)) break;
                        
                        //if has general pins, better for here once
                        //if vars have pins, fork only for that leg
                        env = plan.Next.Aggregate(env, (ac, next) => Perform(next, runner, ac, depth + 1));

                        var inBinds = inputs
                            .Select(v => env[v.Name])
                            .ToDictionary(b => b.Key);

                        foreach (var (k, inBind) in inBinds.Where(kv => kv.Value.Value?.StartsWith("¦") ?? true).ToArray())
                        {
                            var val = inBind.Value;
                            
                            if (val is null)
                            {
                                var found = BindLogServer.DredgeFor(k);
                                val = $"¦{string.Join('¦', found)}";
                            }
                            
                            Console.WriteLine($"pick {k} {val}");
                            Console.WriteLine("@YIELD");
                            var picked = Console.ReadLine();

                            if (picked?.EndsWith('!') ?? false)
                            {
                                picked = picked[..^1];
                                Console.WriteLine($"pin {k} {picked}");
                            }

                            var pickedBind = new Bind(k, picked, "picked");
                            inBinds[k] = pickedBind;
                            env.Add(pickedBind);
                            BindLogServer.Log(pickedBind);
                        }
                        
                        foreach(var (k, inBind) in inBinds) 
                        {
                            Console.WriteLine($"bound {outline.Bid} {inBind.Key} {inBind.Value.ReplaceLineEndings(((char)60).ToString())}");
                        }
                        
                        //TODO store source on binds
                        //TODO emit 'bound' to relay bind to screen

                        var runFlags = depth == 0 ? new[] { "T" } : Array.Empty<string>();

                        var outBinds = runner.Invoke(outline, inBinds, runFlags);

                        return outBinds.Aggregate(env, (ac, b) =>
                        {
                            ac.Add(b);
                            return ac;
                        });
                    
                    case PlanNode.SequencedOr _:
                        break;
                    
                    case PlanNode.SequencedAnd _:
                        return plan.Next.Aggregate(env, (ac, next) => next.Perform(runner, ac, depth));
                }
            }

            return env;
        }
        
        public static Lattice<(ImmutableHashSet<Var> AllInputs, PlanNode Inner)> RoundUpInputs(this Lattice<PlanNode> from)
            => from.MapBottomUp<PlanNode, (ImmutableHashSet<Var> AllInputs, PlanNode Inner)>(
                (node, below) =>
                {
                    var allInps = below.Aggregate(
                        ImmutableHashSet<Var>.Empty,
                        (ac, l) => ac.Union(l.Node.AllInputs)
                    );

                    if (node is PlanNode.Block b)
                    {
                        allInps = allInps.Union(b.Outline.Inputs.Select(v => v.AsSimple()));
                    }

                    //also, need to handle wildcard case
                    
                    return (allInps, node);
                });
    }
}
