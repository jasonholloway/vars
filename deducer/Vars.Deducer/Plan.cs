using System.Collections.Generic;
using System.Linq;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    // public record Plan(PlanNode[] Roots) : PlanNode
    // {
    //     public record NoopNode : PlanNode;
    //     public record BlockNode(Outline Outline, params PlanNode[] Upstreams) : PlanNode;
    //     public record OrNode(params PlanNode[] Nodes) : PlanNode;
    // }

    public abstract record PlanNode
    {
        public record BlockNode(Outline Outline) : PlanNode;
        public record OrNode : PlanNode;
    };

    public record PlanContext;

    public record Plan2(params Lattice<PlanNode>[] Roots) : Lattice<PlanNode>(default, Roots);

    public record Lattice<T>(T Node, params Lattice<T>[] Next) : Lattice;

    public abstract record Lattice
    {
        public static Lattice<T> From<T>(T node, IEnumerable<Lattice<T>> next)
            => new(node, next.ToArray());
        
        public static Lattice<T> From<T>(T node, params Lattice<T>[] next)
            => new(node, next);

    }
}

