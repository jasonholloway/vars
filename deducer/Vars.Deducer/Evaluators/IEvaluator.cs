using Vars.Deducer.Tags;

namespace Vars.Deducer.Evaluators;

public interface IEvaluator<X>
{
    bool TryEval<V>(X x, F<V> tag, out F<V> translated);
    F<V> Eval<V>(X x, F<V> tag);
}