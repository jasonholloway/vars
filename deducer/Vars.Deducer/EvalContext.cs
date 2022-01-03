using System.Collections.Immutable;

namespace Vars.Deducer;

public interface IStateContext<out TSelf, TState> where TSelf : IStateContext<TSelf, TState>
{
    TState Get();
    TSelf Put(TState state);

    TState Zero { get; }
    TState Combine(TState left, TState right);
}

// public record EvalContext(ImmutableDictionary<Type, object> States) : IEvalContext<EvalContext>
// {
//     public static readonly EvalContext Empty = new(ImmutableDictionary<Type, object>.Empty);
//
//     public TState Get<TState>()
//         => States.TryGetValue(typeof(TState), out var found)
//             ? (TState)found
//             : throw new NotImplementedException("need default");
//
//     public EvalContext Put<TState>(TState state)
//         => new(
//             States.SetItem(typeof(TState), state!)
//         );
//
//     public EvalContext CombineWith(EvalContext other)
//     {
//         throw new NotImplementedException();
//     }
// }