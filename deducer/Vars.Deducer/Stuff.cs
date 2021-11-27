using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace Vars.Deducer
{
    public record Outline(string raw);
    public record SpecializedOutline(string raw, Outline parent) : Outline(raw);
    public record Link(Var @var, Outline[] suppliers);
    public record Var();

    public class Outlines
    {
        public readonly Outline[] Items;

        private Outlines(IEnumerable<string> rawOutlines)
        {
            Items = rawOutlines.Select(raw => new Outline(raw)).ToArray();
        }
        
        public static Outlines Parse(string line)
            => new Outlines(line.Split());
    }
    
    public class Deducer
    {
        Outlines _outlines;
        
        public Deducer(Outlines outlines)
        {
            _outlines = outlines;
        }

        public Plan Deduce()
        {
            throw new NotImplementedException();
        }
    }

    public class Plan
    {
        
    }
}