using System;
using System.Collections.Immutable;

namespace Vars.Deducer
{
    public class Env
    {
        ImmutableDictionary<string, string> _current = ImmutableDictionary<string, string>.Empty;
        ImmutableDictionary<string, string[]> _links = ImmutableDictionary<string, string[]>.Empty;

        public void Add(Bind bind)
        {
            _current = _current.SetItem(bind.Key, bind.Value!);
        }

        public void Add((string Name, string Value) bind, params Bind[] upstreams)
            => Add(new Bind(bind.Name, bind.Value, "na", upstreams));
        
        public void Fork((string Name, string Value) bind, params Bind[] upstreams)
        {
            throw new NotImplementedException();
        }

        public void Pop()
        {
            throw new NotImplementedException();
        }
        
        public Bind this[string name] => new(
            name, 
            _current.TryGetValue(name, out var found) ? found : null
            );
    };
}