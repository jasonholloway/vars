using System.Collections.Generic;
using System.Linq;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    public static class Deducer
    {
        public static Outline[] Deduce(OutlineIndex index, IEnumerable<Target> targets)
        {
            var root = new BlockLink(null, targets.Select(index.SummonLink).ToArray());

            var ordered = TopoSorter.Sort(root);

            return ordered;
        }

        public static Outline[] Deduce(OutlineIndex index, params Target[] targets)
            => Deduce(index, targets.AsEnumerable());
    }
}