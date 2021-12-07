using System.Collections.Generic;
using System.Linq;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    using static PlanNode;
    
    public static class FlatPlanner
    {
        public static FlatPlan Plan(OutlineIndex index, IEnumerable<Target> targets)
        {
            var queue = new Queue<Planned>();
            var seen = new HashSet<Lattice<PlanNode>>();
            
            var plan = Planner.Plan(index, targets);
            Visit(plan, 0);
            return new FlatPlan(queue.ToArray());

            void Visit(Lattice<PlanNode> x, int depth)
            {
                if (seen.Contains(x)) return;
                
                seen.Add(x);
                
                switch (x.Node)
                {
                    case null:
                        x.Next.ForEach(u => Visit(u, depth));
                        break;
                    
                    case BlockNode n:
                        x.Next.ForEach(u => Visit(u, depth + 1));
                        queue.Enqueue(new Planned(n.Outline, IsTarget: depth == 0));
                        break;
                    
                    case OrNode n:
                        if (x.Next.FirstOrDefault() is Lattice<PlanNode> first)
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