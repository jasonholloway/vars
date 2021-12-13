using System.Collections.Immutable;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    using static IO;
    
    public static class PlanExtensions2
    {
        public static IO<Env> Perform(this Plan2 plan, IRunner runner, Env? env = null)
            => plan
                .RoundUpInputs()
                .Perform(runner, env ?? new Env(), 0);

        static IO<Env> Perform(this Lattice<(ImmutableHashSet<Var>, PlanNode)> plan, IRunner runner, Env env, int depth)
        {
            if (plan.Node is var (allInputs, node))
            {
                switch (node)
                {
                    case PlanNode.Block((_, _, var inputs, var outputs, var flags) outline):
                        if (depth > 0 && outputs.All(v => env[v.Name].Value != null))
                        {
                            break;
                        }
                        
                        return Thread(plan.Next, env, (e, n) => Perform(n, runner, e, depth + 1))
                            .Then(env =>
                            {
                                var inBinds = inputs
                                    .Select(v => env[v.Name])
                                    .ToDictionary(b => b.Key);

                                var pickables = inBinds
                                    .Where(kv => kv.Value.Value?.StartsWith("¦") ?? true);

                                return Thread(pickables, env, (e, pickable) =>
                                {
                                    var (k, inBind) = pickable;
                                    var val = inBind.Value;

                                    if (val is null)
                                    {
                                        var found = BindLogServer.DredgeFor(k);
                                        val = $"¦{string.Join('¦', found)}";
                                    }

                                    return Say($"pick {k} {val}")
                                        .Then(Say("@YIELD"))
                                        .Then(Hear())
                                        .Then(picked =>
                                        {
                                            if (picked?.EndsWith('!') ?? false)
                                            {
                                                picked = picked[..^1];
                                                return Say($"pin {k} {picked}")
                                                    .Then(_ => Lift(picked));
                                            }

                                            return Lift(picked);
                                        })
                                        .Then(picked =>
                                        {
                                            var pickedBind = new Bind(k, picked, "picked");
                                            inBinds[k] = pickedBind;
                                            e.Add(pickedBind);
                                            BindLogServer.Log(pickedBind);
                                            
                                            //todo inBinds to be passed through
                                            //todo env to be made immutable
                                            //todo IO to thread through env by default

                                            return Lift(e);
                                        });
                                })
                                .Then(env =>
                                    Thread(inBinds, true, 
                                            (_, inBind) => Say($"bound {outline.Bid} {inBind.Key} {inBind.Value.Value.ReplaceLineEndings(((char)60).ToString())}")
                                            )
                                    .Then(Lift(env)))
                                .Then(env =>
                                {
                                    //TODO store source on binds
                                    //TODO emit 'bound' to relay bind to screen

                                    var runFlags = depth == 0 ? new[] { "T" } : Array.Empty<string>();

                                    var outBinds = runner.Invoke(outline, inBinds, runFlags);

                                    return Lift(outBinds.Aggregate(env, (ac, b) =>
                                    {
                                        ac.Add(b);
                                        return ac;
                                    }));
                                });
                            });

                    case PlanNode.SequencedOr _:
                        break;

                    case PlanNode.SequencedAnd _:
                        return Thread(plan.Next, env, (e, n) => n.Perform(runner, e, depth));
                }
            }

            return Lift(env);
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
