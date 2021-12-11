using System;
using System.Collections.Generic;
using System.Linq;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
    public class TestRunner : IRunner
    {
        readonly ILookup<string, Func<Bind[]?>> _responses;
        readonly List<(string Bid, IDictionary<string, Bind> Binds, string[] Flags)> _calls = new();

        public TestRunner(params (string Bid, Func<Bind[]?> GetBinds)[] responses)
        {
            _responses = responses.ToLookup(t => t.Bid, t => t.GetBinds);
        }

        public Bind[] Invoke(Outline outline, IDictionary<string, Bind> binds, string[] flags)
        {
            var bid = outline.Bid;
            
            _calls.Add((bid, binds, flags));
            
            return _responses[bid]
                .Aggregate(
                    new Func<Bind[]>(() => Array.Empty<Bind>()), 
                    (ac, el) => () => ac().Concat(el() ?? Array.Empty<Bind>()).ToArray())
                .Invoke();
        }

        public IEnumerable<(string Bid, IDictionary<string, Bind> Binds, string[] Flags)> Calls => _calls;

        public IEnumerable<string> CalledBids => _calls.Select(c => c.Item1);
    }
}