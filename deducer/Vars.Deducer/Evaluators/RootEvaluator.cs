using Vars.Deducer.Tags;

namespace Vars.Deducer.Evaluators;

public class RootEvaluator<X> : IEvaluator<X>
{
    IEvaluator<X>[] _evals;

    public RootEvaluator(IEnumerable<Func<IEvaluator<X>, IEvaluator<X>>> evalFacs)
    {
        _evals = evalFacs.Select(fac => fac(this)).ToArray();
    }
    
    public bool TryEval<V>(X x, F<V> tag, out F<V> translated)
    {
        foreach (var eval in _evals)
        {
            if (eval.TryEval(x, tag, out translated))
            {
                return true;
            }
        }

        translated = null!;
        return false;
    }

    public F<V> Eval<V>(X x, F<V> tag)
        => TryEval(x, tag, out var translated)
            ? translated
            : tag;
}