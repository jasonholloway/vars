using System.Collections.Immutable;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    using static Ops;
        
    public record RunContext(Env Env, Outline Outline, ImmutableDictionary<string, Bind> InBinds);
    
    public static class PlanExtensions2
    {
        public static M<Env, Env> Perform(this Plan2 plan, IRunner runner)
            => plan
                .RoundUpInputs()
                .Perform(0);

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

        static M<Env, Env> Perform(this Lattice<(ImmutableHashSet<Var>, PlanNode)> plan, int depth)
            => Id<Env>().Then(x =>
            {
                if (plan.Node is var (allInputs, node))
                {
                    switch (node)
                    {
                        case PlanNode.Block((_, _, var inputs, var outputs, var flags) outline):
                            return x.When(
                                @if: x.Read(env => depth == 0 || outputs.Any(v => env[v.Name].Value == null)),
                                then: x
                                    .LoopThru(plan.Next, (_, n) => Perform(n, depth + 1))
                                    .Update(env => new RunContext(
                                        Env: env,
                                        Outline: outline,
                                        InBinds: inputs
                                            .Select(v => env[v.Name])
                                            .ToImmutableDictionary(b => b.Key)
                                        ))
                                    .PickUndecidedInputs()
                                    .EmitBoundInputs()
                                    .SendToRunner(isTarget: depth == 0)
                                    .MergeBinds()
                            );

                        case PlanNode.SequencedOr _:
                            break;

                        case PlanNode.SequencedAnd _:
                            return x.LoopThru(plan.Next, (_, n) => n.Perform(depth));
                    }
                }

                return x;
            });

        public static M<R, RunContext> PickUndecidedInputs<R>(this M<R, RunContext> m)
            => m.Read(s =>
                    s.InBinds
                        .Select(kv => (
                            Name: kv.Key,
                            Options: kv.Value.Value?.Split("¦",
                                StringSplitOptions.RemoveEmptyEntries) ?? Array.Empty<string>()
                        ))
                        .Where(t => t.Options.Length != 1)
                )
                .LoopThru((x, p) => x
                    .When(x.Lift(!p.Options.Any()),
                        then: x.DredgeBindLog(p.Name),
                        @else: x.Lift(p.Options))
                    .Then((x, vals) => x
                        .PickVal(p.Name, vals)
                        .Map(picked => new Bind(p.Name, picked, "picked"))
                        .Then((x, bind) => x
                            .Update(s => s with
                            {
                                Env = s.Env.Add(bind),
                                InBinds = s.InBinds.SetItem(p.Name, bind)
                            })
                            .AppendToBindLog(bind)
                        ))
                );

        public static M<R, RunContext, string?> PickVal<R>(this M<R, RunContext> m, string name, IEnumerable<string> options)
            => m.Say($"pick {name} ¦{string.Join('¦', options)}")
                .Say("@YIELD")
                .Hear()
                .Then((x, pickedVal) =>
                {
                    if (pickedVal?.EndsWith('!') ?? false)
                    {
                        var v = pickedVal[..^1];
                        return x.Say($"pin {name} {v}")
                            .Lift(v);
                    }

                    return x.Lift(pickedVal);
                });
        
        public static M<R, RunContext> EmitBoundInputs<R>(this M<R, RunContext> m)
            => m.Read(s => s.InBinds.Values
                    .Select(b => $"bound {s.Outline.Bid} {b.Key} {b.Value?.ReplaceLineEndings(((char)60).ToString()) ?? string.Empty}")
                )
                .LoopThru((x, line) => x.Say(line));

        public static M<R, RunContext, Bind[]> SendToRunner<R>(this M<R, RunContext> m, bool isTarget)
            => m.ReadThen((x, s) =>
            {
                var runFlags = isTarget ? new[] { "T" } : Array.Empty<string>();
                return x.InvokeRunner(s.Outline, s.InBinds.Values.ToArray(), runFlags);
            });

        public static M<R, Env> MergeBinds<R>(this M<R, RunContext, Bind[]> m)
            => m.Then((x, binds) =>
            {
                //TODO store source on binds
                //TODO emit 'bound' to relay bind to screen
                return x.Update(s =>
                    binds.Aggregate(s.Env, (ac, b) => ac.Add(b))
                    );
            });
    }
}
