using Vars.Deducer.Model;

namespace Vars.Deducer;

public interface M<in R, out W> {}
public interface M<in R, out W, out V> : M<R, W> {}

public static class Ops
{
    public static M<R, W, V> Lift<R, W, V>(this M<R, W> io, V val)
        => io.Then(_ => new Tags.Pure<W, V>(val));
    
    public static M<S, S> Id<S>()
        => new Tags.Id<S>();

    public static M<R, W, W> Read<R, W>(this M<R, W> io)
        => io.Then(_ => new Tags.Read<W>());

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


    public static M<R, W> Write<R, W>(this M<R, R> io, W newState)
        => new Tags.Write<R, W>(newState);

    public static M<R, W> Update<R, W>(this M<R, R> io, Func<R, W> fn)
        => io.Read().Then((x, s) => x.Write(fn(s)));



    public static M<R, W, BV> Map<R, W, AV, BV>(this M<R, W, AV> io, Func<AV, BV> fn)
        => io.Then((x, v) => x.Lift(fn(v)));
    
    
    public static M<AR, BW, BV> Then<AR, AW, AV, BR, BW, BV>(this M<AR, AW, AV> io, Func<M<AW, AW>, AV, M<BR, BW, BV>> fn)
        where AW : BR
        => new Tags.Bind<AR, AW, AV, BR, BW, BV>(io, v => fn(Id<AW>(), v));
    
    public static M<AR, BW, BV> Then<AR, AW, BR, BW, BV>(this M<AR, AW> io, Func<M<AW, AW>, M<BR, BW, BV>> fn)
        where AW : BR
        => new Tags.Bind<AR, AW, BR, BW, BV>(io, () => fn(Id<AW>()));

    public static M<AR, BW> Then<AR, AW, AV, BR, BW>(this M<AR, AW, AV> io, Func<M<AW, AW>, AV, M<BR, BW>> fn)
        where AW : BR
        => io.Then((x, v) => fn(x, v).Lift(default(Nil)));

    public static M<AR, BW> Then<AR, AW, BR, BW>(this M<AR, AW> io, Func<M<AW, AW>, M<BR, BW>> fn)
        where AW : BR
        => io.Then((x) => fn(x).Lift(default(Nil)));
    

    public static M<R, W, Nil> Say<R, W>(this M<R, W> _, string line)
        => new Tags.Say<R, W>(line);

    public static M<R, W, string> Hear<R, W>(this M<R, W> io)
        => io.Then(_ => new Tags.Hear<W>());

    
    public static M<R, W, Bind[]> InvokeRunner<R, W>(this M<R, W> io, Outline outline, Bind[] binds, string[] runFlags)
        => new Tags.InvokeRunner<R, W>(outline, binds, runFlags);
    
    public static M<S, S, string[]> DredgeBindLog<S>(this M<S, S> io, string name)
        => new Tags.DredgeBindLog<S>(name);

    public static M<S, S> AppendToBindLog<S>(this M<S, S> io, Bind bind)
        => new Tags.AppendToBindLog<S>(bind);
    
    
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
    public record Pure<S, V>(V val) : M<S, S, V>;
    
    public record Bind<AR, AW, AV, BR, BW, BV>(M<AR, AW, AV> io, Func<AV, M<BR, BW, BV>> fn) : M<AR, BW, BV>
        where AW : BR;
    
    public record Bind<AR, AW, BR, BW, BV>(M<AR, AW> io, Func<M<BR, BW, BV>> fn) : M<AR, BW, BV>
        where AW : BR;

    public record Read<R> : M<R, R, R>;
    public record Write<R, W>(W val) : M<R, W>;

    public record Say<R, W>(string Line) : M<R, W, Nil>;
    public record Hear<S> : M<S, S, string>;

    public record InvokeRunner<R, W>(Outline Outline, Bind[] Binds, string[] RunFlags) : M<R, W, Bind[]>;
    
    public record DredgeBindLog<S>(string Name) : M<S, S, string[]>;
    public record AppendToBindLog<S>(Bind bind) : M<S, S>;
}

public struct Nil {}