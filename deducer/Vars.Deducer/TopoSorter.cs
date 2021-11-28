using System;
using System.Collections.Generic;
using Vars.Deducer.Model;

public static class TopoSorter
{
    public static Outline[] Sort(BlockLink root)
    {
        var queue = new Queue<Outline>();
        var seen = new HashSet<Outline>();
        
        Visit(root);
        
        return queue.ToArray();

        void Visit(BlockLink b)
        {
            Console.Error.WriteLine($"B {b}");
            
            if (b.Block is Outline ol && seen.Contains(ol))
            {
                return;
            }
            
            foreach (var v in b.Requirements)
            {
                Console.Error.WriteLine($"V {v}");
                foreach (var bb in v.Suppliers)
                {
                    Visit(bb);
                }
            }

            if (b.Block is Outline ol2)
            {
                queue.Enqueue(ol2);
                seen.Add(ol2);
            }
        }
    }
}