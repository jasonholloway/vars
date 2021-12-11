using System.Collections.Generic;
using System.Linq;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    using static PlanNode;
    
    public static class Planner
    {
        public static Plan2 Plan(OutlineIndex index, IEnumerable<Target> rootTargets)
        {
            var seenOutlines = new Dictionary<Outline, Lattice<PlanNode>>();
            
            var rootNodes = rootTargets.Select(VisitTarget).ToArray();
            return new Plan2(rootNodes);

            Lattice<PlanNode> VisitTarget(Target target)
            {
                //CACHE
                
                var (_, suppliers) = index.SummonLink(target);
                var nodes = (
                    from ol in suppliers
                    select VisitOutline(ol)
                ).ToArray();

                return nodes.Length switch
                {
                    0 => new Lattice<PlanNode>(new SequencedAnd()),
                    1 => nodes.Single(),
                    _ => new Lattice<PlanNode>(new SequencedOr(), nodes)
                };
            }

            Lattice<PlanNode> VisitOutline(Outline outline)
            {
                if (seenOutlines.TryGetValue(outline, out var found))
                {
                    return found;
                }
                
                var upstreams = (
                    from v in outline.Inputs 
                    select VisitTarget(new VarTarget(v))
                ).ToArray();

                var node = new Lattice<PlanNode>(new Block(outline), upstreams);
                seenOutlines.Add(outline, node);
                return node;
            }
        }

        public static Plan2 Plan(OutlineIndex index, params Target[] targets)
            => Plan(index, targets.AsEnumerable());
    }
}