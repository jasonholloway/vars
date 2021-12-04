using System.Collections.Generic;
using System.Linq;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    using static Plan;
    
    public static class FlatPlanner
    {
        public static FlatPlan Plan(OutlineIndex index, IEnumerable<Target> targets)
        {
            var queue = new Queue<Planned>();
            var seen = new HashSet<Node>();
            
            var plan = Planner.Plan(index, targets);
            Visit(plan, 0);
            return new FlatPlan(queue.ToArray());

            void Visit(Node node, int depth)
            {
                if (seen.Contains(node)) return;
                
                seen.Add(node);
                
                switch (node)
                {
                    case Plan p:
                        p.Roots.ForEach(u => Visit(u, depth));
                        break;
                    
                    case BlockNode n:
                        n.Upstreams.ForEach(u => Visit(u, depth + 1));
                        queue.Enqueue(new Planned(n.Outline, IsTarget: depth == 0));
                        break;
                    
                    case OrNode n:
                        if (n.Nodes.FirstOrDefault() is Node first)
                        {
                            Visit(first, depth);
                        }
                        break;
                }
            }
        }

        public static FlatPlan Plan(OutlineIndex index, params Target[] targets)
            => Plan(index, targets.AsEnumerable());
    }
}