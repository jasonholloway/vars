using Vars.Deducer.Model;

namespace Vars.Deducer
{
    using static PlanNode;
    
    public static class FlatPlanner
    {
        public static FlatPlan ToFlatPlan(this Plan2 plan)
        {
            var queue = new Queue<Planned>();
            var seen = new HashSet<Lattice<PlanNode>>();

            Visit(plan, 0);
            return new FlatPlan(queue.ToArray());

            void Visit(Lattice<PlanNode> x, int depth)
            {
                if (seen.Contains(x)) return;

                seen.Add(x);

                switch (x.Node)
                {
                    case Block n:
                        x.Next.ForEach(u => Visit(u, depth + 1));
                        queue.Enqueue(new Planned(n.Outline, IsTarget: depth == 0));
                        break;
                    
                    case SequencedAnd:
                        x.Next.ForEach(u => Visit(u, depth));
                        break;

                    case SequencedOr n:
                        if (x.Next.FirstOrDefault() is Lattice<PlanNode> first)
                        {
                            Visit(first, depth);
                        }
                        break;
                }
            }
        }
    }
}