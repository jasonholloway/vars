using System;
using System.Collections.Generic;
using Vars.Deducer.Model;

public static class TopoSorter
{
    public static Planned[] Sort(BlockLink root)
    {
        var queue = new Queue<Planned>();
        var seen = new HashSet<Outline>();
        
        Visit(root, 0);
        
        return queue.ToArray();

        void Visit(BlockLink b, int depth)
        {
            // Console.Error.WriteLine($"B {b}");
            
            if (b.Block is Outline ol && seen.Contains(ol))
            {
                return;
            }
            
            foreach (var v in b.Requirements)
            {
                // Console.Error.WriteLine($"V {v}");
                foreach (var bb in v.Suppliers)
                {
                    Visit(bb, depth + 1);
                }
            }

            if (b.Block is Outline ol2)
            {
                queue.Enqueue(new Planned(ol2, depth <= 1));
                seen.Add(ol2);
            }
        }
    }
}