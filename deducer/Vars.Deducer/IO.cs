namespace Vars.Deducer;

public interface IO<in T1, out T2>
{
    IO<T3, T2> With<T3>() where T3 : T1;
};

public interface IO<out T> : IO<object, T> {}

public abstract record IO
{
    public abstract record _Base<T1, T2> : IO<T1, T2>
    {
        public IO<T3, T2> With<T3>() where T3 : T1
            => (IO<T3, T2>)this;
    }
    
    public record _Id<T> : _Base<T, T>;
    public record _Lift<T>(T val) : _Base<object, T>;
    public record _Bind<T1, T2, T3>(IO<T1, T2> io, Func<T2, IO<Nil, T3>> fn) : _Base<T1, T3>;

    public record _Say(string line) : _Base<object, object>;
    public record _Hear() : _Base<object, string>;
    
    public static IO<object, T> Lift<T>(T val)
        => new _Lift<T>(val);

    public static IO<T, T> Id<T>()
        => new _Id<T>();

    public static IO<T1, T3> Bind<T1, T2, T3>(IO<T1, T2> io, Func<T2, IO<Nil, T3>> fn)
        => new _Bind<T1, T2, T3>(io, fn);

    public static IO<T1, T2> Do<T1, T2>(Func<T1, IO<Nil, T2>> fn)
        => Bind(Id<T1>(), fn);

    public static IO<object, T> Do<T>(Func<IO<Nil, T>> fn)
        => Bind(Id<object>(), _ => fn());

    public static IO<object, object> Say(string line)
        => new _Say(line);

    public static IO<object, string> Hear()
        => new _Hear();
    
    public static IO<TAc, TAc> ForEach<TEl, TAc>(IEnumerable<TEl> els, Func<TEl, IO<TAc, TAc>> fn)
        => els.Aggregate(Id<TAc>(), (io, el) => io.Then(_ => fn(el)));
}

public static class IOExtensions
{
    public static IO<T1, T4> Then<T1, T2, T4>(this IO<T1, T2> io, Func<T2, IO<Nil, T4>> fn)
        => new IO._Bind<T1, T2, T4>(io, fn);

    public static IO<T1, T4> Then<T1, T2, T4>(this IO<T1, T2> io, IO<Nil, T4> io2)
        => io.Then(_ => io2);
}

public struct Nil {}