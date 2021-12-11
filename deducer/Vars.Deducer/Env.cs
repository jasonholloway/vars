using System;
using System.Collections.Immutable;

namespace Vars.Deducer
{
    public class Env
    {
        ImmutableDictionary<string, string> _current = ImmutableDictionary<string, string>.Empty;
        ImmutableDictionary<string, string[]> _links = ImmutableDictionary<string, string[]>.Empty;

        public void Bind((string Name, string Value) bind, params Bind[] upstreams)
        {
            _current = _current.SetItem(bind.Name, bind.Value);
            
            //how is the graph going to be shaped?
            //we want to check consistency, mostly
            //when forking, a new graph is created with incompatibles removed
            
            //the roots of the graph are in the current context
            //
            //
        }
        
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