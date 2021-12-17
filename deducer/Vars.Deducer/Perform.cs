using System.Collections.Immutable;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    using static Ops;
    
    public static class PlanExtensions2
    {
        public static IO<Env> Perform(this Plan2 plan, IRunner runner)
            => plan
                .RoundUpInputs()
                .Perform(runner, 0)
                .Then(Read());

        static IO Perform(this Lattice<(ImmutableHashSet<Var>, PlanNode)> plan, IRunner runner, int depth)
        {
            if (plan.Node is var (allInputs, node))
            {
                switch (node)
                {
                    case PlanNode.Block((_, _, var inputs, var outputs, var flags) outline):
                        return When(
                            @if: Read(env => depth > 0 && outputs.All(v => env[v.Name].Value != null)),
                            @then: 
                                ForEach(plan.Next, n => Perform(n, runner, depth + 1))
                                .Then(Read(e => inputs
                                        .Select(v => e[v.Name])
                                        .ToDictionary(b => b.Key))
                                )
                                .Then(inBinds =>
                                {
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

                                                return Lift(picked);
                                            })
                                            .Then(picked =>
                                            {
                                                var pickedBind = new Bind(k, picked, "picked");
                                                inBinds[k] = pickedBind;
                                                //!!!!!!

                                                return Update(e =>
                                                {
                                                    e.Add(pickedBind);
                                                    BindLogServer.Log(pickedBind);

                                                    return e;
                                                });
                                            });
                                    })
                                    .Then(ForEach(inBinds,
                                        inBind => Say(
                                            $"bound {outline.Bid} {inBind.Key} {inBind.Value.Value.ReplaceLineEndings(((char)60).ToString())}"))
                                    )
                                    .Then(() =>
                                    {
                                        //TODO store source on binds
                                        //TODO emit 'bound' to relay bind to screen

                                        var runFlags = depth == 0 ? new[] { "T" } : Array.Empty<string>();

                                        var outBinds = runner.Invoke(outline, inBinds, runFlags);

                                        return Update(env => 
                                            outBinds.Aggregate(env, (ac, b) =>
                                            {
                                                ac.Add(b);
                                                return ac;
                                            }));
                                    });
                                }),
                            @else: Id()
                        );

                    case PlanNode.SequencedOr _:
                        break;

                    case PlanNode.SequencedAnd _:
                        return ForEach(plan.Next, n => n.Perform(runner, depth));
                }
            }

            return Id();
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
