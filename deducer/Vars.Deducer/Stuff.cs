using System;
using System.Collections.Generic;
using System.Linq;

namespace Vars.Deducer
{
    public record SpecializedOutline(string raw, Outline parent);
    public record Link(Var @var, Outline[] suppliers);

    public record Pin(string VarName, string Value)
    {
        public static Pin Parse(string raw)
        {
            var parts = raw.Split('=');
            return new Pin(
                parts.ElementAt(0),
                parts.ElementAt(1)
                );
        }

        public override string ToString()
            => $"{VarName}={Value}";
    }

    public class Var
    {
        public string Name { get; }
        public ISet<Pin>? Pins { get; }
        readonly int _hash;

        public Var(string name, ISet<Pin>? pins = null)
        {
            Name = name;
            Pins = pins;
            _hash = name.GetHashCode() + pins?.Aggregate(13, (ac, p) => ac + p.GetHashCode()) ?? 0;
        }
        
        public static Var Parse(string raw)
        {
            var parts = raw.Split('{', StringSplitOptions.TrimEntries);

            var pinBody = parts.ElementAtOrDefault(1)?.Split('}').ElementAtOrDefault(0);
            var pinParts = pinBody?.Split('+') ?? Array.Empty<string>();
            var pins = pinParts.Select(Pin.Parse).ToHashSet();
            
            return new Var(parts.ElementAt(0), pins);
        }

        public override string ToString()
            => (Pins?.Any() ?? false) 
                ? $"{Name}{{{string.Join('+', Pins.Select(p => p.ToString()))}}}"
                : Name;

        public override bool Equals(object? obj)
            => obj is Var other
               && Name.Equals(other.Name)
               && (
                   Pins == other.Pins
                   || (Pins is ISet<Pin> left 
                       && other.Pins is ISet<Pin> right
                       && left.SetEquals(right))
               );

        public override int GetHashCode()
            => _hash;
    }

    public record Outline(string Bid, string[] Names, Var[] Inputs, Var[] Outputs, string[] Flags)
    {
        public static Outline Parse(string raw)
        {
            var parts = raw.Split(';', StringSplitOptions.TrimEntries);
            return new Outline(
                parts.ElementAt(0), 
                parts.ElementAt(1).Split(','),
                parts.ElementAt(2).Split(',').Select(Var.Parse).ToArray(),
                parts.ElementAt(3).Split(',').Select(Var.Parse).ToArray(),
                parts.ElementAt(4).Split(',')
                );
        }

        public override string ToString()
            => string.Join(';', 
                Bid, 
                string.Join(',', Names), 
                string.Join(',', Inputs.Select(i => i.ToString())), 
                string.Join(',', Outputs.Select(o => o.ToString())), 
                string.Join(',', Flags)
                );
    }

    public class Outlines
    {
        public readonly Outline[] Items;

        private Outlines(IEnumerable<Outline> outlines)
        {
            Items = outlines.ToArray();
        }
        
        public static Outlines Parse(string line)
            => new Outlines(line.Split().Select(Outline.Parse));
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