using System.Collections.Immutable;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    using static IO;
    
    public static class PlanExtensions2
    {
        public static IO<Env, Env> Perform(this Plan2 plan, IRunner runner)
            => plan
                .RoundUpInputs()
                .Perform(runner, 0);

        static IO<Env, Env> Perform(this Lattice<(ImmutableHashSet<Var>, PlanNode)> plan, IRunner runner, int depth)
        {
            if (plan.Node is var (allInputs, node))
            {
                switch (node)
                {
                    case PlanNode.Block((_, _, var inputs, var outputs, var flags) outline):
                        return Do((Env env) =>
                        {
                            if (depth > 0 && outputs.All(v => env[v.Name].Value != null))
                            {
                                return Id<Env>();
                            }
                            
                            return ForEach(plan.Next, n => Perform(n, runner, depth + 1))
                                .Then(env =>
                                {
                                    var inBinds = inputs
                                        .Select(v => env[v.Name])
                                        .ToDictionary(b => b.Key);

                                    var pickables = inBinds
                                        .Where(kv => kv.Value.Value?.StartsWith("¦") ?? true);

                                    return ForEach(pickables, pickable =>
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
                                                        .Then(Lift(picked));
                                                }

                                                return Id<string>();
                                            })
                                            .Then(picked =>
                                            {
                                                var pickedBind = new Bind(k, picked, "picked");
                                                inBinds[k] = pickedBind;

                                                return Do((Env e) =>
                                                {
                                                    e.Add(pickedBind);
                                                    BindLogServer.Log(pickedBind);
                                                
                                                    //todo inBinds to be passed through
                                                    //todo env to be made immutable
                                                    //todo IO to thread through env by default
                                                
                                                    return Lift(e);
                                                });
                                            })
                                            .With<Env>();
                                    })
                                    .Then(env =>
                                        ForEach(inBinds, inBind => Say($"bound {outline.Bid} {inBind.Key} {inBind.Value.Value.ReplaceLineEndings(((char)60).ToString())}"))
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
                                })
                                .With<Env>();
                        });

                    case PlanNode.SequencedOr _:
                        break;

                    case PlanNode.SequencedAnd _:
                        return ForEach(plan.Next, n => n.Perform(runner, depth))
                            .With<Env>();
                }
            }

            return Id<Env>();
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
