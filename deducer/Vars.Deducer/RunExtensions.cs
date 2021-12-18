namespace Vars.Deducer;

public static class RunExtensions
{
    public static Func<Env, (Env, T)> Eval<T>(M<,,> io)
        => _Eval((dynamic)io);

    static Func<Env, (Env, T)> _Eval<T>(Tags.Id<T> id)
        => e => (e, default);

    static Func<object, T> _Eval<T>(Tags.Lift<T> lift)
        => _ => lift.val;

    static Func<T1, T3> _Eval<T1, T2, T3>(Tags.Bind<,> bind)
        => v1 =>
        {
            var v2 = Eval(bind.io).Invoke(v1);
            var next = bind.fn(v2);

            var fn = Eval(next);
            return fn(v1);
        };

    static object _Eval(object _)
        => throw new NotImplementedException();
}