using System.Linq;
using System.Text;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    public record Plan(Planned[] Outlines)
    {
        public override string ToString()
            => Outlines.Aggregate(
                new StringBuilder(),
                (ac, ol) => ac.AppendLine(ol.ToString())
            ).ToString();
    }
}