namespace Vars.Deducer;

public static class RunExtensions
{
    public static Func<R, (W, V)> Eval<R, W, V>(this M<R, W, V> io)
        => _Eval((dynamic)io);
    
    public static Func<R, (W, Nil)> Eval<R, W>(this M<R, W> io)
        => _Eval((dynamic)io);

    static Func<S, (S, Nil)> _Eval<S>(Tags.Id<S> id)
        => s => (s, default);

    static Func<S, (S, V)> _Eval<S, V>(Tags.Lift<S, V> lift)
        => s => (s, lift.val);
    
    static Func<AR, (BW, BV)> _Eval<AR, AW, BR, BW, BV>(Tags.Bind<AR, AW, BR, BW, BV> bind)
        where AW : BR
        => ar =>
        {
            var (aw, _) = Eval(bind.io)(ar);
            
            var second = bind.fn();
            return Eval(second)(aw);
        };
    
    //todo: would be nice _not_ to have to have subtly different Bind handlings here - need nicer composition

    static Func<AR, (BW, BV)> _Eval<AR, AW, AV, BR, BW, BV>(Tags.Bind<AR, AW, AV, BR, BW, BV> bind)
        where AW : BR
        => ar =>
        {
            var (aw, av) = Eval(bind.io)(ar);
            
            var second = bind.fn(av);
            return Eval(second)(aw);
        };
    
    static Func<W, (W, W)> _Eval<R, W>(Tags.Read<R, W> read)
        => s => (s, s);
    
    static Func<W, (W, Nil)> _Eval<R, W>(Tags.Write<R, W> write)
        => _ => (write.val, default);

    static object _Eval(object o)
        => throw new NotImplementedException($"Can't evaluate {o.GetType()}");
}