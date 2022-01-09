using Vars.Deducer.Tags;

namespace Vars.Deducer.Evaluators;

public abstract class EvaluatorBase<X> : IEvaluator<X>
{
    protected readonly IEvaluator<X> Root;

    protected EvaluatorBase(IEvaluator<X> root)
    {
        Root = root;
    }

    bool IEvaluator<X>.TryEval<V>(X x, F<V> m, out Cont<X, V> cont)
    {
        cont = ((dynamic)this).Match(x, (dynamic)m);
        return cont != null;
    }

    Cont<X, V> IEvaluator<X>.Eval<V>(X x, F<V> m)
        => ((IEvaluator<X>)this)
            .TryEval(x, m, out var cont) 
                ? cont 
                : throw new NotImplementedException($"Couldn't handle {m}");

    protected object Match(X x, object m) => null!;
}