using System;
using System.Linq;

namespace Vars.Deducer.Model
{
    public record Outline(string Bid, string[] Names, Var[] Inputs, Var[] Outputs, string[] Flags)
    {
        public static Outline Parse(string raw)
        {
            var parts = raw.Split(';', StringSplitOptions.TrimEntries);
            return new Outline(
                parts.ElementAt(0), 
                parts.ElementAtOrDefault(1)?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries) ?? Array.Empty<string>(),
                parts.ElementAtOrDefault(2)?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).Select(Var.Parse).ToArray() ?? Array.Empty<Var>(),
                parts.ElementAtOrDefault(3)?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).Select(Var.Parse).ToArray() ?? Array.Empty<Var>(),
                parts.ElementAtOrDefault(4)?.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries) ?? Array.Empty<string>()
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
}