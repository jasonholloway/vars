using System.Collections.Immutable;

namespace Vars.Deducer
{
    public record Env(ImmutableDictionary<string, string> Current, ImmutableDictionary<string, string[]> Links)
    {
        public static Env Empty = new Env(
            ImmutableDictionary<string, string>.Empty,
            ImmutableDictionary<string, string[]>.Empty
            );

        public Env Add(Bind bind)
            => this with { Current = Current.SetItem(bind.Key, bind.Value!) };

        public Env Add((string Name, string Value) bind, params Bind[] upstreams)
            => Add(new Bind(bind.Name, bind.Value, "na", upstreams));
        
        public Env Fork((string Name, string Value) bind, params Bind[] upstreams)
        {
            throw new NotImplementedException();
        }

        public Env Pop()
        {
            throw new NotImplementedException();
        }
        
        public Bind this[string name] => new(
            name, 
            Current.TryGetValue(name, out var found) ? found : null
            );
    };
}