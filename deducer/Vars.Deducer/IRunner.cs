using System.Collections.Generic;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    public interface IRunner
    {
        Bind[] Invoke(Outline outline, IDictionary<string, Bind> binds, string[] flags);
    }
}