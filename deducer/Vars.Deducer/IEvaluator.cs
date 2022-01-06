namespace Vars.Deducer;

public interface IEvaluator<X>
{
    bool TryEval<V>(X x, F<V> m, out Cont<X, V> cont);
    Cont<X, V> Eval<V>(X x, F<V> m);
}