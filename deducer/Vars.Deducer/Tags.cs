using Vars.Deducer.Model;

namespace Vars.Deducer;

public interface M<in R, out W> {}
public interface M<in R, out W, out V> : M<R, W> {}

public static class Ops
{
    public static M<R, W, V> Lift<R, W, V>(this M<R, W> io, V val)
        => new Tags.Lift<R, W, V>(val);
    
    public static M<S, S> Id<S>()
        => new Tags.Id<S>();

    public static M<R, W, W> Read<R, W>(this M<R, W> io)
        => throw new NotImplementedException();

    public static M<R, W, V> Read<R, W, V>(this M<R, W> io, Func<W, V> fn)
        => io.Read().Then((x, s) => x.Lift(fn(s)));

    public static M<AR, BW, BV> ReadThen<AR, AW, BR, BW, BV>(this M<AR, AW> io, Func<M<AW, AW>, AW, M<BR, BW, BV>> fn)
        where AW : BR
        => io.Read().Then(fn);
    
    public static M<AR, BW> ReadThen<AR, AW, BR, BW>(this M<AR, AW> io, Func<M<AW, AW>, AW, M<BR, BW>> fn)
        where AW : BR
        => io.Read().Then(fn);
    
    // public static IO<AR, BW, BV> Read<AR, AW, BR, BW, BV>(this IO<AR, AW> io, Func<IO<AW, AW>, AW, IO<BR, BW, BV>> fn)
    //     where AW : BR
    //     => io.Read().Then((x, s) => fn(x, s));

    
    public static M<S1, S2> Write<S1, S2>(this M<S1, S1> io, S2 state)
        => throw new NotImplementedException();

    public static M<S1, S2> Update<S1, S2>(this M<S1, S1> io, Func<S1, S2> fn)
        => io.Read().Then((x, s) => x.Write(fn(s)));



    public static M<R, W, BV> Map<R, W, AV, BV>(this M<R, W, AV> io, Func<AV, BV> fn)
        => io.Then((x, v) => x.Lift(fn(v)));
    
    
    public static M<AR, BW, BV> Then<AR, AW, AV, BR, BW, BV>(this M<AR, AW, AV> io, Func<M<AW, AW>, AV, M<BR, BW, BV>> fn)
        where AW : BR
        => new Tags.Bind<AR, AW, AV, BR, BW, BV>(io, v => fn(Id<AW>(), v));

    public static M<AR, BW, BV> Then<AR, AW, BR, BW, BV>(this M<AR, AW> io, Func<M<AW, AW>, M<BR, BW, BV>> fn)
        where AW : BR
        => throw new NotImplementedException(); // new Tags.Bind<AR, AW, object, BR, BW, BV>(io, _ => fn());

    public static M<AR, BW> Then<AR, AW, AV, BR, BW>(this M<AR, AW, AV> io, Func<M<AW, AW>, AV, M<BR, BW>> fn)
        where AW : BR
        => io.Then((x, v) => fn(x, v).Lift(new Nil()));
    
    public static M<AR, BW> Then<AR, AW, BR, BW>(this M<AR, AW> io, Func<M<AW, AW>, M<BR, BW>> fn)
        where AW : BR
        => throw new NotImplementedException(); // new Tags.Bind<AR, AW, object, BR, BW, BV>(io, _ => fn());
    

    public static M<R, W, Nil> Say<R, W>(this M<R, W> _, string line)
        => new Tags.Say<R, W>(line);

    public static M<R, W, string> Hear<R, W>(this M<R, W> _)
        => new Tags.Hear<R, W>();

    
    public static M<R, W, Bind[]> InvokeRunner<R, W>(this M<R, W> io, Outline outline, Bind[] binds, string[] runFlags)
        => new Tags.InvokeRunner<R, W>(outline, binds, runFlags);
    
    public static M<R, W, string[]> DredgeBindLog<R, W>(this M<R, W> io, string name)
        => new Tags.DredgeBindLog<R, W>(name);

    public static M<R, W> AppendToBindLog<R, W>(this M<R, W> io, Bind bind)
        => new Tags.AppendToBindLog<R, W>(bind);
    
    
    public static M<AR, AW> LoopThru<AR, AW, El>(this M<AR, AW> io, IEnumerable<El> through, Func<M<AW, AW>, El, M<AW, AW>> @do)
        => io.Then(x => through.Aggregate(x, (ac, el) => ac.Then(x => @do(x, el))));

    public static M<AR, AW> LoopThru<AR, AW, El>(this M<AR, AW, IEnumerable<El>> io,
        Func<M<AW, AW>, El, M<AW, AW>> @do)
        => io.Then((x, els) => x.LoopThru(els, @do));

    
    public static M<R, BW> When<R, W, AR, AW, BR, BW>(this M<R, W> io, M<AR, AW, bool> @if, M<BR, BW> @then, M<BR, BW> @else)
        where W : AR
        where AW : BR
        => io.Then(_ => @if).Then((_, result) => result ? then : (@else));
    
    public static M<R, BW, BV> When<R, W, AR, AW, BR, BW, BV>(this M<R, W> io, M<AR, AW, bool> @if, M<BR, BW, BV> @then, M<BR, BW, BV> @else)
        where W : AR
        where AW : BR
        => io.Then(_ => @if).Then((_, result) => result ? then : @else);
    
    public static M<R, S> When<R, W, S>(this M<R, W> io, M<S, S, bool> @if, M<S, S> @then)
        where W : S
        => io.Then(_ => @if).Then((x, result) => result ? then : x);
}



public abstract record Tags
{
    public record Id<S> : M<S, S>;
    public record Lift<R, W, V>(V val) : M<R, W, V>;
    
    public record Bind<AR, AW, AV, BR, BW, BV>(M<AR, AW, AV> io, Func<AV, M<BR, BW, BV>> fn) : M<AR, BW, BV>
        where AW : BR;

    public record Say<R, W>(string Line) : M<R, W, Nil>;
    public record Hear<R, W> : M<R, W, string>;

    public record InvokeRunner<R, W>(Outline Outline, Bind[] Binds, string[] RunFlags) : M<R, W, Bind[]>;
    
    public record DredgeBindLog<R, W>(string Name) : M<R, W, string[]>;
    public record AppendToBindLog<R, W>(Bind bind) : M<R, W>;
}

public static class IOExtensions
{
    
    
    // public static IO<T2?> When<T1, T2>(this IO<T1> io, Predicate<T1> predicate)
    //     => io.Then(v => predicate(v) ?   )
    
    
}

public struct Nil {}