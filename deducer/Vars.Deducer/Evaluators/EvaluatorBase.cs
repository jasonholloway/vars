using Vars.Deducer.Tags;

namespace Vars.Deducer.Evaluators;

public abstract class EvaluatorBase<X> : IEvaluator<X>
{
    protected readonly IEvaluator<X> _root;

    protected EvaluatorBase(IEvaluator<X> root)
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