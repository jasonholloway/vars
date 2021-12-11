using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.IO;
using System.Linq;
using System.Net;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
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

                        foreach (var (k, v) in inBinds.Where(kv => kv.Value.Value?.StartsWith("¦") ?? true).ToArray())
                        {
                            if (v.Value is null)
                            {
                                //DREDGE HERE

                                // File.ReadLines("")
                                //     .Reverse();

                            }
                            
                            Console.WriteLine($"pick {k} {v.Value}");
                            Console.WriteLine("@YIELD");
                            var picked = Console.ReadLine();

                            if (picked?.EndsWith('!') ?? false)
                            {
                                picked = picked[..^1];
                                Console.WriteLine($"pin {k} {picked}");
                            }
                            
                            inBinds[k] = new Bind(k, picked);
                        }
                        
                        //TODO dredge context file
                        //TODO store source on binds
                        //TODO emit 'bound' to relay bind to screen

                        var runFlags = depth == 0 ? new[] { "T" } : Array.Empty<string>();

                        var outBinds = runner.Invoke(outline, inBinds, runFlags);

                        foreach (var bind in outBinds)
                        {
                            env.Bind((bind.Key, bind.Value));
                        }
                        
                        break;
                    
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
