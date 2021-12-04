using Vars.Deducer.Model;

namespace Vars.Deducer
{
    public record Plan(Node[] Roots) : Node
    {
        public record NoopNode : Node;
        public record BlockNode(Outline Outline, params Node[] Upstreams) : Node;
        public record OrNode(params Node[] Nodes) : Node;
    }
    
    public abstract record Node;

    public record PlanContext;





    public record SemiLattice<TNode>(TNode Join);


}