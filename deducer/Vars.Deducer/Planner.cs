using System.Collections.Generic;
using System.Linq;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    using static Plan;
    
    public static class Planner
    {
        public static Plan Plan(OutlineIndex index, IEnumerable<Target> rootTargets)
        {
            var seenOutlines = new Dictionary<Outline, Node>();
            
            var rootNodes = rootTargets.Select(VisitTarget).ToArray();
            return new Plan(rootNodes);

            Node VisitTarget(Target target)
            {
                //CACHE
                
                var (_, suppliers) = index.SummonLink(target);
                var nodes = (
                    from ol in suppliers
                    select VisitOutline(ol)
                ).ToArray();

                return nodes.Length switch
                {
                    0 => new NoopNode(),
                    1 => nodes.Single(),
                    _ => new OrNode(nodes)
                };
            }

            Node VisitOutline(Outline outline)
            {
                if (seenOutlines.TryGetValue(outline, out var found))
                {
                    return found;
                }
                
                var upstreams = (
                    from v in outline.Inputs 
                    select VisitTarget(new VarTarget(v))
                ).ToArray();

                var node = new BlockNode(outline, upstreams);
                seenOutlines.Add(outline, node);
                return node;
            }
        }

        public static Plan Plan(OutlineIndex index, params Target[] targets)
            => Plan(index, targets.AsEnumerable());
    }
}