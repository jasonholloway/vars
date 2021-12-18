using System.Collections.Immutable;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    using static Ops;
    
    public static class PlanExtensions2
    {
        public static IO<Env, Env> Perform(this Plan2 plan, IRunner runner)
            => plan
                .RoundUpInputs()
                .Perform(runner, 0);

        static IO<Env, Env> Perform(this Lattice<(ImmutableHashSet<Var>, PlanNode)> plan, IRunner runner, int depth)
            => Id<Env>().Then(x =>
            {
                if (plan.Node is var (allInputs, node))
                {
                    switch (node)
                    {
                        case PlanNode.Block((_, _, var inputs, var outputs, var flags) outline):
                            return x.When(
                                
                                @if: x.Read(env => depth > 0 && outputs.All(v => env[v.Name].Value != null)),
                                
                                @then: x.ForEach(plan.Next, (_, n) => Perform(n, runner, depth + 1))
                                    .Read(e => inputs
                                        .Select(v => e[v.Name])
                                        .ToDictionary(b => b.Key))
                                    .Then((x, inBinds) =>
                                    {
                                        var pickables = inBinds
                                            .Where(kv => kv.Value.Value?.StartsWith("¦") ?? true);

                                        return x.ForEach(pickables, (x, pickable) =>
                                            {
                                                var (k, inBind) = pickable;
                                                var val = inBind.Value;

                                                if (val is null)
                                                {
                                                    var found = BindLogServer.DredgeFor(k);
                                                    val = $"¦{string.Join('¦', found)}";
                                                }

                                                return x
                                                    .Say($"pick {k} {val}")
                                                    .Say("@YIELD")
                                                    .Hear()
                                                    .Then((x, picked) =>
                                                    {
                                                        if (picked?.EndsWith('!') ?? false)
                                                        {
                                                            picked = picked[..^1];
                                                            return x.Say($"pin {k} {picked}")
                                                                .Lift(picked);
                                                        }

                                                        return x.Lift(picked);
                                                    })
                                                    .Then((x, picked) =>
                                                    {
                                                        var pickedBind = new Bind(k, picked, "picked");
                                                        inBinds[k] = pickedBind;
                                                        //!!!!!!

                                                        return x.Update(e =>
                                                        {
                                                            e.Add(pickedBind);
                                                            BindLogServer.Log(pickedBind);

                                                            return e;
                                                        });
                                                    });
                                            })
                                            .ForEach(inBinds, (x, inBind) => 
                                                x.Say($"bound {outline.Bid} {inBind.Key} {inBind.Value.Value.ReplaceLineEndings(((char)60).ToString())}")
                                            )
                                            .Then(x =>
                                            {
                                                //TODO store source on binds
                                                //TODO emit 'bound' to relay bind to screen

                                                var runFlags = depth == 0 ? new[] { "T" } : Array.Empty<string>();

                                                var outBinds = runner.Invoke(outline, inBinds, runFlags);

                                                return x.Update(env =>
                                                    outBinds.Aggregate(env, (ac, b) =>
                                                    {
                                                        ac.Add(b);
                                                        return ac;
                                                    }));
                                            });
                                    }),
                                @else: x
                            );

                        case PlanNode.SequencedOr _:
                            break;

                        case PlanNode.SequencedAnd _:
                            return x.ForEach(plan.Next, (_, n) => n.Perform(runner, depth));
                    }
                }

                return x;
            });

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
