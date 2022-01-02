namespace Vars.Deducer;

public interface IEvaluator
{
    bool TryEval<S, V>(S state, F<V> m, out Cont<S, V> cont);
    Cont<S, V> Eval<S, V>(S state, F<V> m);
}