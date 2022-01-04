namespace Vars.Deducer;

public abstract class Evaluator : IEvaluator
{
    protected readonly IEvaluator _root;

    protected Evaluator(IEvaluator root)
    {
        _root = root;
    }

    public bool TryEval<S, V>(S state, F<V> m, out Cont<S, V> cont)
    {
        cont = ((dynamic)this).Match((dynamic)state, (dynamic)m);
        return cont != null;
    }

    public Cont<S, V> Eval<S, V>(S state, F<V> m)
        => TryEval(state, m, out var cont) 
            ? cont 
            : throw new NotImplementedException($"Couldn't handle {m}");

    protected object Match<S, M>(S state, M m) => null!;
}

public class RootEvaluator : IEvaluator
{
    IEvaluator[] _evals;
    
    public RootEvaluator(params Func<IEvaluator, IEvaluator>[] facs)
    {
        _evals = facs.Select(fn => fn(this)).ToArray();
    }

    public bool TryEval<S, V>(S state, F<V> m, out Cont<S, V> cont)
    {
        foreach (var eval in _evals)
        {
            if (eval.TryEval(state, m, out cont))
            {
                return true;
            }
            else
            {
                Console.WriteLine("hello");
            }
        }

        cont = null!;
        return false;
    }

    public Cont<S, V> Eval<S, V>(S state, F<V> m)
        => TryEval(state, m, out var cont)
            ? cont
            : throw new NotImplementedException($"Can't handle {m}");
}

public class CoreEvaluator : Evaluator
{
    public CoreEvaluator(IEvaluator root) 
        : base(root) {}

    public Cont<S, Nil> Match<S>(S s, Tags.Id _)
        => new Return<S, Nil>(s, default);

    public Cont<S, V> Match<S, V>(S s, Tags.Pure<V> pure)
        => new Return<S, V>(s, pure.val);


    public Cont<S, BV> Match<S, AV, BV>(S s, Tags.FMap<AV, BV> tag)
        => _root.Eval(s, tag.io)
            .FlatMap(t => _root.Eval(t.Item1, tag.fn(t.Item2)));


    public Cont<S, R> Match<S, R>(S s, Tags.Read<R> _)
        where S : IStateContext<S, R>
        => new Return<S, R>(s, s.Get());
    
    // public Cont<object, R> Match<R>(object s, Tags.Read<R> _)
    //     => new Return<object, R>(s, default);
    
    public Cont<S, Nil> Match<S, W>(S s, Tags.Write<W> write)
        where S : IStateContext<S, W>
        => new Return<S, Nil>(s.Put(write.val), default);
}

public interface IEvalContext<TSelf>
{
    TState Get<TState>();
    TSelf Put<TState>(TState state);
    TSelf CombineWith(TSelf other);
}
