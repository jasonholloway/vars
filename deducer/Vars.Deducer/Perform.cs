using System.Collections.Immutable;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    using static Ops;
        
    public record RunContext(Env Env, Outline Outline, ImmutableDictionary<string, Bind> InBinds);
    
    public static class PlanExtensions2
    {
        public static F<Env> Perform(this Plan2 plan)
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

        static F<Env> Perform(this Lattice<(ImmutableHashSet<Var>, PlanNode)> plan, int depth)
        {
            if (plan.Node is var (allInputs, node))
            {
                switch (node)
                {
                    case PlanNode.Block((_, _, var inputs, var outputs, var flags) outline):
                        return When(
                            @if: ReadMap((Env env) => depth == 0 || outputs.Any(v => env[v.Name].Value == null)),
                            then: Pure(plan.Next)
                                .LoopThru(n => Perform(n, depth + 1))
                                .Then(
                                    ReadWrite((Env env) => new RunContext(
                                        Env: env, //no need to nest now...
                                        Outline: outline,
                                        InBinds: inputs
                                            .Select(v => env[v.Name])
                                            .ToImmutableDictionary(b => b.Key)
                                        )))
                                .Then(PickUndecidedInputs)
                                .Then(EmitBoundInputs)
                                .Then(SendToRunner(isTarget: depth == 0))
                                .Then(MergeBinds)
                        );

                    case PlanNode.SequencedOr _:
                        break;

                    case PlanNode.SequencedAnd _:
                        return Pure(plan.Next).LoopThru(n => n.Perform(depth));
                }
            }

            return null; //Id();
        }

        public static F<Nil> PickUndecidedInputs()
            => ReadMap((RunContext s) =>
                    s.InBinds
                        .Select(kv => (
                            Name: kv.Key,
                            Options: kv.Value.Value?.Split("¦",
                                StringSplitOptions.RemoveEmptyEntries) ?? Array.Empty<string>()
                        ))
                        .Where(t => t.Options.Length != 1)
                )
                .LoopThru(p =>
                    When(
                        @if: Pure(!p.Options.Any()),
                        then: DredgeBindLog(p.Name),
                        @else: Pure(p.Options)
                    )
                    .Then(vals =>
                        PickVal(p.Name, vals)
                            .Map(picked => new Bind(p.Name, picked, "picked"))
                            .Then(bind =>
                                ReadWrite((RunContext s) => s with
                                    {
                                        Env = s.Env.Add(bind), //this should be updated separately
                                        InBinds = s.InBinds.SetItem(p.Name, bind)
                                    })
                                    .Then(AppendToBindLog(bind))
                            ))
                );

        public static F<string?> PickVal(string name, IEnumerable<string> options)
            => Say($"pick {name} ¦{string.Join('¦', options)}")
                .Then(Say("@YIELD"))
                .Then(Hear)
                .Then(pickedVal =>
                {
                    if (pickedVal?.EndsWith('!') ?? false)
                    {
                        var v = pickedVal[..^1];
                        return Say($"pin {name} {v}")
                            .Then(Pure(v));
                    }

                    return Pure(pickedVal);
                });
        
        public static F<Nil> EmitBoundInputs()
            => ReadMap((RunContext s) => s.InBinds.Values
                    .Select(b => $"bound {s.Outline.Bid} {b.Key} {b.Value?.ReplaceLineEndings(((char)60).ToString()) ?? string.Empty}")
                )
                .LoopThru(line => Say(line));

        public static F<Bind[]> SendToRunner(bool isTarget)
            => ReadThen((RunContext s) =>
            {
                var runFlags = isTarget ? new[] { "T" } : Array.Empty<string>();
                return InvokeRunner(s.Outline, s.InBinds.Values.ToArray(), runFlags);
            });

        public static F<Env> MergeBinds(Bind[] binds)
        {
            //TODO store source on binds
            //TODO emit 'bound' to relay bind to screen
            return ReadWrite((RunContext s) =>
                    binds.Aggregate(s.Env, (ac, b) => ac.Add(b)))
                .Then(Read<Env>);
        }
    }
}
