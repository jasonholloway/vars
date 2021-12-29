namespace Vars.Deducer;

public abstract class Evaluator : IEvaluator
{
    protected readonly IEvaluator _root;

    protected Evaluator(IEvaluator root)
    {
        _root = root;
    }

    public bool TryEval<R, W, V>(R state, M<R, W, V> m, out Cont<W, V> cont)
    {
        cont = ((dynamic)this).Match((dynamic)state!, (dynamic)m);
        return cont != null;
    }

    public bool TryEval<R, W>(R state, M<R, W> m, out Cont<W, Nil> cont)
    {
        cont = ((dynamic)this).Match((dynamic)state!, (dynamic)m);
        return cont != null;
    }

    public Cont<W, V> Eval<R, W, V>(R state, M<R, W, V> m)
        => TryEval(state, m, out var cont) 
            ? cont 
            : throw new NotImplementedException($"Couldn't handle {m}");

    public Cont<W, Nil> Eval<R, W>(R state, M<R, W> m)
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

    public bool TryEval<R, W, V>(R state, M<R, W, V> m, out Cont<W, V> cont)
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

    public bool TryEval<R, W>(R state, M<R, W> m, out Cont<W, Nil> cont)
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

    public Cont<W, V> Eval<R, W, V>(R state, M<R, W, V> m)
        => TryEval(state, m, out var cont)
            ? cont
            : throw new NotImplementedException($"Can't handle {m}");

    public Cont<W, Nil> Eval<R, W>(R state, M<R, W> m)
        => TryEval(state, m, out var cont)
            ? cont
            : throw new NotImplementedException($"Can't handle {m}");
}

public class CoreEvaluator : Evaluator
{
    public CoreEvaluator(IEvaluator root) 
        : base(root) {}

    public Cont<S, Nil> Match<S>(S s, Tags.Id<S> _)
        => new Return<S, Nil>(s, default);

    public Cont<S, V> Match<S, V>(S s, Tags.Pure<S, V> pure)
        => new Return<S, V>(s, pure.val);


    public Cont<BW, BV> Match<AR, AW, AV, BR, BW, BV>(AR ar, Tags.FMap<AR, AW, AV, BR, BW, BV> tag)
        where AW : BR
        => _root.Eval(ar, tag.io)
            .FlatMap(t => _root.Eval(t.Item1, tag.fn(t.Item2)));

    public Cont<BW, BV> Match<AR, AW, BR, BW, BV>(AR ar, Tags.Bind<AR, AW, BR, BW, BV> tag)
        where AW : BR
        => _root.Eval(ar, tag.io)
            .FlatMap(t => _root.Eval(t.Item1, tag.fn()));
    
    
    public Cont<R, R> Match<R>(R s, Tags.Read<R> _)
        => new Return<R, R>(s, s);
    
    public Cont<W, Nil> Match<R, W>(R _, Tags.Write<R, W> write)
        => new Return<W, Nil>(write.val, default);
}