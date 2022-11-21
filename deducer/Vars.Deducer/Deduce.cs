using System.Collections.Immutable;
using Vars.Deducer.Model;
using Vars.Deducer.Tags;

namespace Vars.Deducer
{
    using static Ops;
    using static DeducerOps;
        
    public record RunContext(Outline Outline, ImmutableDictionary<string, Bind> InBinds);
    public record PlanNodeWithVars(PlanNode Node, ImmutableHashSet<Var> AllInputs);
    
    public static class PlanExtensions2
    {
        public static Tag<Env> Deduce(this Plan2 plan)
        {
            var plan2 = plan.GatherVars();
            var allVarNames = plan2.Node.AllInputs.Select(v => v.Name).ToArray();

            return GetUserPins(allVarNames)
                .Then(MergeBinds)
                .Then(WalkNodes(plan2, 0));
        }

        public static Lattice<PlanNodeWithVars> GatherVars(this Lattice<PlanNode> from)
                => from.MapBottomUp<PlanNode, PlanNodeWithVars>(
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

                        return new PlanNodeWithVars(node, allInps);
                    });

        static Tag<Env> WalkNodes(Lattice<PlanNodeWithVars> plan, int depth)
        {
            if (plan.Node is var (node, allInputs))
            {
                switch (node)
                {
                    case PlanNode.Block((_, _, var inputs, var outputs, var flags) outline):
                        return When(
                            @if: ReadMap((Env env) => depth == 0 || outputs.Any(v => env[v.Name].Value == null)),
                            then: Pure(plan.Next)
                                .LoopThru(n => WalkNodes(n, depth + 1))
                                .Then(
                                    ReadWrite((Env env) => new RunContext(
                                        Outline: outline,
                                        InBinds: inputs
                                            .Select(v => env[v.Name])
                                            .ToImmutableDictionary(b => b.Key)
                                        )))
                                .Then(PickUndecidedInputs)
                                .Then(EmitBoundInputs)
                                .Then(SendToRunner(isTarget: depth == 0))
                                .Then(MergeBinds)
                                .Then(Read<Env>)
                        );

                    case PlanNode.SequencedOr _:
                        break;

                    case PlanNode.SequencedAnd _:
                        return Pure(plan.Next)
                            .LoopThru(n => WalkNodes(n, depth))
                            .Then(Read<Env>);
                }
            }

            return Read<Env>();
        }

        public static Tag<Nil> PickUndecidedInputs()
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
                        PickValue(p.Name, vals)
                            .Map(picked => new Bind(p.Name, picked, "picked"))
                            .Then(bind =>
                                Id()
                                    .Then(ReadWrite((Env env) => env.Add(bind)))
                                    .Then(ReadWrite((RunContext s) => s with
                                    {
                                        InBinds = s.InBinds.SetItem(p.Name, bind)
                                    }))
                                    .Then(AppendToBindLog(bind))
                            ))
                );

        public static Tag<string?> PickVal(string name, IEnumerable<string> options)
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
        
        public static Tag<Nil> EmitBoundInputs()
            => ReadMap((RunContext s) => s.InBinds.Values
                    .Select(b => $"bound {s.Outline.Bid} {b.Key} {b.Value?.ReplaceLineEndings(((char)60).ToString()) ?? string.Empty}")
                )
                .LoopThru(line => Say(line));

        public static Tag<Bind[]> SendToRunner(bool isTarget)
            => ReadThen((RunContext s) =>
            {
                var runFlags = isTarget ? new[] { "T" } : Array.Empty<string>();
                return InvokeRunner(s.Outline, s.InBinds.Values.ToArray(), runFlags);
            });

        public static Tag<Nil> MergeBinds(Bind[] binds)
        {
            //TODO store source on binds
            //TODO emit 'bound' to relay bind to screen
            return ReadWrite((Env env) => binds.Aggregate(env, (ac, b) => ac.Add(b)));
        }
    }
}