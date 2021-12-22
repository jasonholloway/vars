using System.Data;

namespace Vars.Deducer;

public abstract record Result<W, V>;
public sealed record Return<W, V>(W state, V Val) : Result<W, V>;
public sealed record Yield<W, V>(object State, object Evaluable, Func<(object State, object Evaluable), Result<W, V>> Next) : Result<W, V>;

public static class RunExtensions
{
    public static Result<W, V> Eval<R, W, V>(this M<R, W, V> io, R state)
        => Eval(io)(state);
    
    public static Func<R, Result<W, V>> Eval<R, W, V>(this M<R, W, V> io)
        => _Eval((dynamic)io);
    
    public static Func<R, Result<W, Nil>> Eval<R, W>(this M<R, W> io)
        => _Eval((dynamic)io);

    static Func<S, Result<S, Nil>> _Eval<S>(Tags.Id<S> id)
        => s => new Return<S, Nil>(s, default);

    static Func<S, Result<S, V>> _Eval<S, V>(Tags.Lift<S, V> lift)
        => s => new Return<S, V>(s, lift.val);


    static Func<AR, Result<BW, BV>> _Eval<AR, AW, AV, BR, BW, BV>(Tags.Bind<AR, AW, AV, BR, BW, BV> bind)
        where AW : BR
        => ar =>
        {
            var result1 = Eval(bind.io)(ar);
            return EvalResult(result1);

            Result<BW, BV> EvalResult(Result<AW, AV> result)
            {
                switch (result)
                {
                    case Return<AW, AV>(var aw, var av):
                        var second = bind.fn(av);
                        return Eval(second)(aw);
                    
                    case Yield<AW, AV>(var s, var m, var fn) y:
                        return new Yield<BW, BV>(s, m,
                            args =>
                            {
                                var intermediate = fn(args);
                                return EvalResult(intermediate);
                            });
                    
                    default: 
                        throw new InvalidOperationException();
                }
            }
        };
    
    static Func<AR, (BW, BV)> _Eval<AR, AW, BR, BW, BV>(Tags.Bind<AR, AW, BR, BW, BV> bind)
        where AW : BR
        => ar =>
        {
            var (aw, _) = Eval(bind.io)(ar);
            
            var second = bind.fn();
            return Eval(second)(aw);
        };
    
    //todo: would be nice _not_ to have to have subtly different Bind handlings here - need nicer composition
    
    static Func<W, (W, W)> _Eval<R, W>(Tags.Read<R, W> read)
        => s => (s, s);
    
    static Func<W, (W, Nil)> _Eval<R, W>(Tags.Write<R, W> write)
        => _ => (write.val, default);
    
    static object _Eval<T, R, W, V>(T tag) where T : M<R, W, V>
        => throw new NotImplementedException($"SNOOOOOOO");

    static object _Eval(object o)
        => throw new NotImplementedException($"Can't evaluate {o.GetType()}");
}