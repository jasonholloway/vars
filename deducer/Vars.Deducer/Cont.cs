namespace Vars.Deducer;

public interface Cont<W, V>
{
    Cont<W, V2> Map<V2>(Func<V, V2> fn);
    Cont<W2, V2> FlatMap<W2, V2>(Func<(W, V), Cont<W2, V2>> fn);
    
    ValueTask<(W, V)> ToTask(IEvaluator eval);
    (W, V) Run(IEvaluator eval);
}

public sealed record Return<W, V>(W State, V Val) : Cont<W, V>
{
    public Cont<W, V2> Map<V2>(Func<V, V2> fn)
        => new Return<W, V2>(State, fn(Val));

    public Cont<W2, V2> FlatMap<W2, V2>(Func<(W, V), Cont<W2, V2>> fn)
        => fn((State, Val));

    public ValueTask<(W, V)> ToTask(IEvaluator eval)
        => ValueTask.FromResult((State, Val));

    public (W, V) Run(IEvaluator eval)
        => (State, Val);
}

public sealed record Yield<AR, AW, AV, BW, BV>(AR State, M<AR, AW, AV> Evaluable, Func<AW, AV, Cont<BW, BV>> Next) : Cont<BW, BV>
{
    public Cont<BW, BV2> Map<BV2>(Func<BV, BV2> fn)
        => new Yield<AR, AW, AV, BW, BV2>(
            State, 
            Evaluable,
            (aw, av) => Next(aw, av).Map(fn));

    public Cont<W2, V2> FlatMap<W2, V2>(Func<(BW, BV), Cont<W2, V2>> fn)
        => new Yield<AR, AW, AV, W2, V2>(
            State, 
            Evaluable,
            (aw, av) => Next(aw, av).FlatMap(fn));

    public async ValueTask<(BW, BV)> ToTask(IEvaluator eval)
    {
        var (aw, av) = await eval.Eval(State, Evaluable).ToTask(eval);
        return await Next(aw, av).ToTask(eval);
    }

    public (BW, BV) Run(IEvaluator eval)
    {
        var (aw, av) = eval.Eval(State, Evaluable).Run(eval);
        return Next(aw, av).Run(eval);
    }
}

public sealed record Yield<R, W, V>(R State, M<R, W, V> Evaluable) : Cont<W, V>
{
    public Cont<W, V2> Map<V2>(Func<V, V2> fn)
        => new Yield<R, W, V2>(State, Evaluable.Then((x, v) => x.Lift(fn(v))));

    public Cont<W2, V2> FlatMap<W2, V2>(Func<(W, V), Cont<W2, V2>> fn)
    {
        throw new NotImplementedException();
    }

    public ValueTask<(W, V)> ToTask(IEvaluator eval)
        => eval.Eval(State, Evaluable).ToTask(eval);

    public (W, V) Run(IEvaluator eval)
        => eval.Eval(State, Evaluable).Run(eval);
}