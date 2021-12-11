using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    public static class PlanExtensions2
    {
        public static Env Perform(this Plan2 plan, IRunner runner, Env? env = null)
            => plan
                .RoundUpInputs()
                .Perform(runner, env);
        
        public static Env Perform(this Lattice<(ImmutableHashSet<Var>, PlanNode)> plan, IRunner runner, Env? env = null)
        {
            env ??= new Env();

            if (plan.Node is var (inputs, node))
            {
                switch (node)
                {
                    case PlanNode.Block(Outline(var bid, _, _, var outputs, var flags)):
                        if (outputs.Any(v => env[v.Name].Value == null))
                        {
                            //if has general pins, better for here once
                            //if vars have pins, fork only for that leg
                            env = plan.Next.Aggregate(env, (ac, next) => Perform(next, runner, ac));
                            
                            var binds = runner.Invoke(bid, new Dictionary<string, Bind>(), new string[0]);

                            foreach (var bind in binds)
                            {
                                env.Bind((bind.Key, bind.Value));
                            }
                        }
                        
                        break;
                    
                    case PlanNode.SequencedOr _:
                        break;
                    
                    case PlanNode.SequencedAnd _:
                        return plan.Next.Aggregate(env, (ac, next) => next.Perform(runner, ac));
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