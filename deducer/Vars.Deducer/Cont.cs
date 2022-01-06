using System.Reactive.Linq;

namespace Vars.Deducer;

public interface IContResult<out X, out V>
{
    X State { get; }
    V Value { get; }
}

internal record ContResult<X, V>(X State, V Value) : IContResult<X, V>;


public interface Cont<X, out V>
{
    Cont<X, V2> Map<V2>(Func<V, V2> fn);
    Cont<X, V2> FlatMap<V2>(Func<X, V, Cont<X, V2>> fn);

    IObservable<IContResult<X, V>> ToObservable(IEvaluator<X> eval);
    IContResult<X, V> Run(IEvaluator<X> eval);
}

public sealed record Return<X, V>(X State, V Val) : Cont<X, V>
{
    public Cont<X, V2> Map<V2>(Func<V, V2> fn)
        => new Return<X, V2>(State, fn(Val));

    public Cont<X, V2> FlatMap<V2>(Func<X, V, Cont<X, V2>> fn)
        => fn(State, Val);

    public IObservable<IContResult<X, V>> ToObservable(IEvaluator<X> eval)
        => Observable.Return(new ContResult<X, V>(State, Val));

    public IContResult<X, V> Run(IEvaluator<X> eval)
        => new ContResult<X, V>(State, Val);
}

public sealed record Yield<X, AV, BV>(X State, F<AV> Evaluable, Func<X, AV, Cont<X, BV>> Next) : Cont<X, BV>
{
    public Cont<X, CV> Map<CV>(Func<BV, CV> fn)
        => new Yield<X, AV, CV>(
            State, 
            Evaluable,
            (aw, av) => Next(aw, av).Map(fn));

    public Cont<X, CV> FlatMap<CV>(Func<X, BV, Cont<X, CV>> fn)
        => new Yield<X, AV, CV>(
            State, 
            Evaluable,
            (aw, av) => Next(aw, av).FlatMap(fn));

    public IObservable<IContResult<X, BV>> ToObservable(IEvaluator<X> eval)
        => eval.Eval(State, Evaluable).ToObservable(eval)
            .SelectMany(result => Next(result.State, result.Value).ToObservable(eval));

    public IContResult<X, BV> Run(IEvaluator<X> eval)
    {
        var result = eval.Eval(State, Evaluable).Run(eval);
        return Next(result.State, result.Value).Run(eval);
    }
}

public sealed record Yield<X, V>(X State, F<V> Evaluable) : Cont<X, V>
{
    public Cont<X, V2> Map<V2>(Func<V, V2> fn)
        => new Yield<X, V2>(State, Evaluable.Map(fn));

    public Cont<X, V2> FlatMap<V2>(Func<X, V, Cont<X, V2>> fn)
        => throw new NotImplementedException();

    public IObservable<IContResult<X, V>> ToObservable(IEvaluator<X> eval)
        => eval.Eval(State, Evaluable).ToObservable(eval);

    public IContResult<X, V> Run(IEvaluator<X> eval)
        => eval.Eval(State, Evaluable).Run(eval);
}