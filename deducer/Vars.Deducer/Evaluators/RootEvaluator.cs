using Vars.Deducer.Tags;

namespace Vars.Deducer.Evaluators;

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
        }

        cont = null!;
        return false;
    }

    public Cont<X, V> Eval<V>(X x, F<V> m)
        => TryEval(x, m, out var cont)
            ? cont
            : throw new NotImplementedException($"Can't handle {m}");
}