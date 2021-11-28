using System.Linq;

namespace Vars.Deducer.Model
{
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
}