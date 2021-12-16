namespace Vars.Deducer;

public static class RunExtensions
{
    public static T2 Eval<T1, T2>(this IO<T1, T2> io, T1 input)
        => Eval(io).Invoke(input);
    
    static Func<T1, T2> Eval<T1, T2>(IO<T1, T2> io)
        => _Eval((dynamic)io);

    static Func<T, T> _Eval<T>(IO._Id<T> id)
        => v => v;

    static Func<object, T> _Eval<T>(IO._Lift<T> lift)
        => _ => lift.val;

    static Func<T1, T3> _Eval<T1, T2, T3>(IO._Bind<T1, T2, object, T3> bind)
        => v1 =>
        {
            var v2 = Eval(bind.io).Invoke(v1);
            var v3 = bind.fn(v2);
            return Eval(v3).Invoke(new object());
        };
}