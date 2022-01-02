namespace Vars.Deducer;

public interface Cont<S, V>
{
    Cont<S, V2> Map<V2>(Func<V, V2> fn);
    Cont<S2, V2> FlatMap<S2, V2>(Func<(S, V), Cont<S2, V2>> fn);
    
    ValueTask<(S, V)> ToTask(IEvaluator eval);
    (S, V) Run(IEvaluator eval);
}

public sealed record Return<S, V>(S State, V Val) : Cont<S, V>
{
    public Cont<S, V2> Map<V2>(Func<V, V2> fn)
        => new Return<S, V2>(State, fn(Val));

    public Cont<S2, V2> FlatMap<S2, V2>(Func<(S, V), Cont<S2, V2>> fn)
        => fn((State, Val));

    public ValueTask<(S, V)> ToTask(IEvaluator eval)
        => ValueTask.FromResult((State, Val));

    public (S, V) Run(IEvaluator eval)
        => (State, Val);
}

public sealed record Yield<AS, AV, BS, BV>(AS State, F<AV> Evaluable, Func<AS, AV, Cont<BS, BV>> Next) : Cont<BS, BV>
{
    public Cont<BS, CV> Map<CV>(Func<BV, CV> fn)
        => new Yield<AS, AV, BS, CV>(
            State, 
            Evaluable,
            (aw, av) => Next(aw, av).Map(fn));

    public Cont<CS, CV> FlatMap<CS, CV>(Func<(BS, BV), Cont<CS, CV>> fn)
        => new Yield<AS, AV, CS, CV>(
            State, 
            Evaluable,
            (aw, av) => Next(aw, av).FlatMap(fn));

    public async ValueTask<(BS, BV)> ToTask(IEvaluator eval)
    {
        var (aw, av) = await eval.Eval(State, Evaluable).ToTask(eval);
        return await Next(aw, av).ToTask(eval);
    }

    public (BS, BV) Run(IEvaluator eval)
    {
        var (aw, av) = eval.Eval(State, Evaluable).Run(eval);
        return Next(aw, av).Run(eval);
    }
}

public sealed record Yield<S, V>(S State, F<V> Evaluable) : Cont<S, V>
{
    public Cont<S, V2> Map<V2>(Func<V, V2> fn)
        => new Yield<S, V2>(State, Evaluable.Map(fn));

    public Cont<S2, V2> FlatMap<S2, V2>(Func<(S, V), Cont<S2, V2>> fn)
    {
        throw new NotImplementedException();
    }

    public ValueTask<(S, V)> ToTask(IEvaluator eval)
        => eval.Eval(State, Evaluable).ToTask(eval);

    public (S, V) Run(IEvaluator eval)
        => eval.Eval(State, Evaluable).Run(eval);
}

public interface IMonoid<TState>
{
    TState Zero { get; }
    TState Combine(TState left, TState right); //what if can't be combined?
}