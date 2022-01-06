using System.Collections.Immutable;
using System.Dynamic;
using System.Linq.Expressions;

namespace Vars.Deducer;

public abstract record EvaluatorBuilder
{
    public static EvaluatorBuilder<X> WithContext<X>()
        => new(ImmutableList<Func<IEvaluator<X>, IEvaluator<X>>>.Empty);
}

public record EvaluatorBuilder<X>(ImmutableList<Func<IEvaluator<X>, IEvaluator<X>>> EvalFacs) : EvaluatorBuilder
{
    public IEvaluator<X> Build() => new RootEvaluator<X>(EvalFacs);
}


public class RootEvaluator<X> : IEvaluator<X>
{
    IEvaluator<X>[] _evals;

    public RootEvaluator(IEnumerable<Func<IEvaluator<X>, IEvaluator<X>>> evalFacs)
    {
        _evals = evalFacs.Select(fac => fac(this)).ToArray();
    }
    
    public bool TryEval<V>(X x, F<V> m, out Cont<X, V> cont)
    {
        foreach (var eval in _evals)
        {
            if (eval.TryEval(x, m, out cont))
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

    public Cont<X, V> Eval<V>(X x, F<V> m)
        => TryEval(x, m, out var cont)
            ? cont
            : throw new NotImplementedException($"Can't handle {m}");
}


public abstract class Evaluator<X> : IEvaluator<X>
{
    protected readonly IEvaluator<X> _root;

    protected Evaluator(IEvaluator<X> root)
    {
        _root = root;
    }

    public bool TryEval<V>(X x, F<V> m, out Cont<X, V> cont)
    {
        cont = ((dynamic)this).Match(x, (dynamic)m);
        return cont != null;
    }

    public Cont<X, V> Eval<V>(X x, F<V> m)
        => TryEval(x, m, out var cont) 
            ? cont 
            : throw new NotImplementedException($"Couldn't handle {m}");

    protected object Match(X x, object m) => null!;
}


public static class CoreEvaluatorExtensions
{
    public static EvaluatorBuilder<X> AddCoreEvaluator<X>(this EvaluatorBuilder<X> builder) 
        => new(builder.EvalFacs.Add(root => new CoreEvaluator<X>(root)));
}

public class CoreEvaluator<X> : Evaluator<X>
{
    public CoreEvaluator(IEvaluator<X> root) 
        : base(root) {}
    
    public Cont<X, Nil> Match(X x, Tags.Id _)
        => new Return<X, Nil>(x, default);

    public Cont<X, V> Match<V>(X x, Tags.Pure<V> tag)
        => new Return<X, V>(x, tag.val);


    public Cont<X, BV> Match<AV, BV>(X x, Tags.FMap<AV, BV> tag)
        => _root.Eval(x, tag.io)
            .FlatMap((x2, av) => _root.Eval(x2, tag.fn(av)));


    public Cont<X, R> Match<R>(X x, Tags.Read<R> tag)
        => x is IState<X, R> state
            ? new Return<X, R>(x, state.Get())
            : throw new NotImplementedException($"Context doesn't implement {typeof(IState<X, R>)}");
    
    public Cont<X, Nil> Match<W>(X x, Tags.Write<W> tag)
        => x is IState<X, W> state
            ? new Return<X, Nil>(state.Put(tag.val), default)
            : throw new NotImplementedException($"Context doesn't implement {typeof(IState<X, W>)}");
}