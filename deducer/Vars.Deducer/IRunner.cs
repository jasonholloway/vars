using System.Collections.Generic;

namespace Vars.Deducer
{
    public interface IRunner
    {
        Bind[] Invoke(string bid, IDictionary<string, Bind> binds, string[] flags);
    }
}