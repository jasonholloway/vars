using System.Diagnostics;

namespace Vars.Deducer;

public interface IO<in R, out W> {}
public interface IO<in R, out W, out V> : IO<R, W> {}

public static class Ops
{
    public static IO<R, W, V> Lift<R, W, V>(this IO<R, W> io, V val)
        => new Tags.Lift<R, W, V>(val);
    
    public static IO<S, S> Id<S>()
        => new Tags.Id<S>();

    public static IO<S, S, S> Read<S>(this IO<S, S> io)
        => throw new NotImplementedException();

    public static IO<S, S, V> Read<S, V>(this IO<S, S> io, Func<S, V> fn)
        => io.Read().Then((x, s) => x.Lift(fn(s)));

    public static IO<S1, S2> Write<S1, S2>(this IO<S1, S1> io, S2 state)
        => throw new NotImplementedException();

    public static IO<S1, S2> Update<S1, S2>(this IO<S1, S1> io, Func<S1, S2> fn)
        => io.Read().Then((x, s) => x.Write(fn(s)));
    
    
    public static IO<AR, BW, BV> Then<AR, AW, AV, BR, BW, BV>(this IO<AR, AW, AV> io, Func<IO<AW, AW>, AV, IO<BR, BW, BV>> fn)
        where AW : BR
        => new Tags.Bind<AR, AW, AV, BR, BW, BV>(io, v => fn(Id<AW>(), v));

    public static IO<AR, BW, BV> Then<AR, AW, BR, BW, BV>(this IO<AR, AW> io, Func<IO<AW, AW>, IO<BR, BW, BV>> fn)
        where AW : BR
        => throw new NotImplementedException(); // new Tags.Bind<AR, AW, object, BR, BW, BV>(io, _ => fn());

    public static IO<AR, BW> Then<AR, AW, AV, BR, BW>(this IO<AR, AW, AV> io, Func<IO<AW, AW>, AV, IO<BR, BW>> fn)
        where AW : BR
        => io.Then((x, v) => fn(x, v).Lift(new Nil()));
    
    public static IO<AR, BW> Then<AR, AW, BR, BW>(this IO<AR, AW> io, Func<IO<AW, AW>, IO<BR, BW>> fn)
        where AW : BR
        => throw new NotImplementedException(); // new Tags.Bind<AR, AW, object, BR, BW, BV>(io, _ => fn());
    

    public static IO<S, S> Say<S>(this IO<S, S> _, string line)
        => new Tags.Say<S>(line);

    public static IO<R, W, string> Hear<R, W>(this IO<R, W> _)
        => new Tags.Hear<R, W>();
    
    
    public static IO<S, S> ForEach<S, El>(this IO<S, S> io, IEnumerable<El> els, Func<IO<S, S>, El, IO<S, S>> fn)
        => els.Aggregate(io, (ac, el) => ac.Then(x => fn(x, el)));

    
    public static IO<R, BW> When<R, W, AR, AW, BR, BW>(this IO<R, W> io, IO<AR, AW, bool> @if, IO<BR, BW> @then, IO<BR, BW> @else)
        where W : AR
        where AW : BR
        => io.Then(_ => @if).Then((_, result) => result ? then : @else);
    
    
    // public static IO Then<T1>(this IO<T1> io, Func<T1, IO> fn)
    //     => new Tags.Bind<T1, Nil>(io, v => fn(v).Then(Ops.Lift(default(Nil))));
    //
    // public static IO<T2> Then<T1, T2>(this IO<T1> io, IO<T2> io2)
    //     => io.Then(_ => io2);
    //
    //
    // public static IO<T> Then<T>(this IO io, Func<IO<T>> fn)
    //     => throw new NotImplementedException();
    //
    // public static IO<T> Then<T>(this IO io, IO<T> io2)
    //     => throw new NotImplementedException();
    //
    // public static IO Then(this IO io, IO io2)
    //     => throw new NotImplementedException();
}



public abstract record Tags
{
    public record Id<S> : IO<S, S>;
    public record Lift<R, W, V>(V val) : IO<R, W, V>;
    
    public record Bind<AR, AW, AV, BR, BW, BV>(IO<AR, AW, AV> io, Func<AV, IO<BR, BW, BV>> fn) : IO<AR, BW, BV>
        where AW : BR;

    public record Say<S>(string Line) : IO<S, S>;
    public record Hear<R, W> : IO<R, W, string>;
}

public static class IOExtensions
{
    
    
    // public static IO<T2?> When<T1, T2>(this IO<T1> io, Predicate<T1> predicate)
    //     => io.Then(v => predicate(v) ?   )
    
    
}

public struct Nil {}