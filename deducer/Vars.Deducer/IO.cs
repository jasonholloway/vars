namespace Vars.Deducer;

// public record IOContext(TextReader In, TextWriter Out);

public record IO<T> : IO
{
    public record Id(T val) : IO<T>;
    public record Cont(Func<IO<T>> fn) : IO<T>;
}



public abstract record IO
{
    public static IO<T> Lift<T>(T val)
        => new IO<T>.Id(val);

    public static IO<T2> Bind<T1, T2>(IO<T1> io, Func<T1, IO<T2>> fn)
        => null;

    public static IO<T> Do<T>(Func<IO<T>> fn)
        => new IO<T>.Cont(fn);

    public static IO<bool> Say(string line)
        => null;

    public static IO<string?> Hear()
        => null;

    public static IO<TAc> Thread<TEl, TAc>(IEnumerable<TEl> els, TAc seed, Func<TAc, TEl, IO<TAc>> fn)
        => els.Aggregate(Lift(seed), (io, el) => io.Then(ac => fn(ac, el)));
}

public static class IOExtensions
{
    public static IO<T2> Then<T1, T2>(this IO<T1> io, Func<T1, IO<T2>> fn)
        => IO.Bind(io, fn);

    public static IO<T2> Then<T1, T2>(this IO<T1> io, IO<T2> io2)
        => io.Then(_ => io2);

}

// public static class IOContextExtensions
// {
//     public static void Say(this IOContext x, string line)
//         => x.Out.WriteLine(line);
//     
//     public static string? Hear(this IOContext x)
//         => x.In.ReadLine();
// }



