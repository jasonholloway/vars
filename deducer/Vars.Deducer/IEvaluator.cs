namespace Vars.Deducer;

public interface IEvaluator
{
    bool TryEval<R, W, V>(R state, M<R, W, V> m, out Cont<W, V> cont);
    bool TryEval<R, W>(R state, M<R, W> m, out Cont<W, Nil> cont);
    
    Cont<W, V> Eval<R, W, V>(R state, M<R, W, V> m);
    Cont<W, Nil> Eval<R, W>(R state, M<R, W> m);
}