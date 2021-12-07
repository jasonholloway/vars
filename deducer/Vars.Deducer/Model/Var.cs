using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using System.Linq;

namespace Vars.Deducer.Model
{
    public abstract record Target();
    public record VarTarget(Var Var) : Target;
    public record BlockTarget(string BlockName) : Target;
    
    //if var given, then we synthesize block
    //this could even be done before deducer
    //if someone wants var, then we should do 'get:varName'
    //deducer does vars, but we receive blocks
    //get:varName is received, with correct input var - flows straight through, like
    //frontend speaks in blocks - in outlines even
    //doesn't need to prepen block to anything
    //
    //but deducer speaks in targets
    //
    //
    //
    
    public class Var : IEquatable<Var>
    {
        public string Name { get; }
        public ISet<Pin>? Pins { get; }
        readonly int _hash;

        public Var(string name, ISet<Pin>? pins = null)
        {
            Name = name;
            Pins = pins ?? ImmutableSortedSet<Pin>.Empty;
            _hash = name.GetHashCode() + (pins?.Aggregate(13, (ac, p) => ac + p.GetHashCode()) ?? 13);
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

        public bool Equals(Var? other)
            => other != null
               && Name.Equals(other.Name)
               && (
                   Pins == other.Pins
                   || (Pins is ISet<Pin> left 
                       && other.Pins is ISet<Pin> right
                       && left.SetEquals(right))
               );

        public override bool Equals(object? obj)
            => obj is Var other && Equals(other);

        public override int GetHashCode()
            => _hash;
    }

    public static class VarExtensions
    {
        public static Var AsSimple(this Var @var)
            => (@var.Pins?.Any() ?? false)
                ? new Var(@var.Name)
                : @var;
    }
}