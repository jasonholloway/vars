using System;
using System.Linq;

namespace Vars.Deducer
{
    public interface ILatticeVisitor<in TFrom, TTo>
    {
        Lattice<TTo> Visit(TFrom node, Lattice<TTo>[] visited);
    }
    
    
    
    public static class LatticeExtensions
    {
        public static Lattice<TTo> Map<TFrom, TTo>(this Lattice<TFrom> from, Func<TFrom?, TTo> map)
            => from.MapBottomUp<TFrom, TTo>(
                (n, _) => map(n)
            );

        public static Lattice<TTo> MapBottomUp<TFrom, TTo>(
            this Lattice<TFrom> from,
            Func<TFrom, Lattice<TTo>[], TTo> map)
            => from.VisitBottomUp<TFrom, TTo>(
                (n, visited) => new Lattice<TTo>(map(n, visited), visited)
            );
        
        public static Lattice<TTo> VisitBottomUp<TFrom, TTo>(this Lattice<TFrom> from, Func<TFrom?, Lattice<TTo>[], Lattice<TTo>> visit)
        {
            var next = from.Next
                .Select(l => VisitBottomUp(l, visit))
                .ToArray();

            return visit(from.Node, next);
        }

        public static Lattice<TTo> VisitBottomUp<TFrom, TTo>(this Lattice<TFrom> from,
            ILatticeVisitor<TFrom, TTo> visitor)
            => from.VisitBottomUp<TFrom, TTo>(visitor.Visit);
        
        // public static Lattice<TTo> VisitBottomUp<TFrom, TTo, TVisitor>(this Lattice<TFrom> from,
        //     ILatticeVisitor<TFrom, TTo> visitor)
        //     => from.VisitBottomUp<TFrom, TTo>(visitor.Visit);


    }
}