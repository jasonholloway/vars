using Vars.Deducer.Tags;

namespace Vars.Deducer.Evaluators;

public abstract class EvaluatorBase<X> : IEvaluator<X>
{
    protected readonly IEvaluator<X> Root;

    protected EvaluatorBase(IEvaluator<X> root)
    {
        Root = root;
    }

    bool IEvaluator<X>.TryEval<V>(X x, F<V> tag, out F<V> translated)
    {
        translated = ((dynamic)this).Match(x, (dynamic)tag);
        return translated != null;
    }

    F<V> IEvaluator<X>.Eval<V>(X x, F<V> tag)
        => ((IEvaluator<X>)this)
            .TryEval(x, tag, out var cont) 
                ? cont 
                : throw new NotImplementedException($"Couldn't handle {tag}");

    protected object Match(X x, object m) => null!;
}