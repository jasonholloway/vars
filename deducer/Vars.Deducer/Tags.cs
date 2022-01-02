using Vars.Deducer.Model;

namespace Vars.Deducer;

public interface M<in R, out W> {}
public interface M<in R, out W, out V> : M<R, W> {}

public interface F<out V> {}

public struct Nil {}

public static class Ops
{
    public static F<V> Pure<V>(V val)
        => new Tags.Pure<V>(val);
    
    public static F<Nil> Id()
        => new Tags.Id();
    
    
    public static F<BV> Then<AV, BV>(this F<AV> io, Func<AV, F<BV>> fn)
        => new Tags.FMap<AV, BV>(io, fn);
    
    public static F<BV> Then<AV, BV>(this F<AV> io, Func<F<BV>> fn)
        => new Tags.FMap<AV, BV>(io, _ => fn());
    
    public static F<BV> Then<AV, BV>(this F<AV> io, F<BV> next)
        => new Tags.FMap<AV, BV>(io, _ => next);
    
    
    public static F<BV> Map<AV, BV>(this F<AV> io, Func<AV, BV> fn)
        => io.Then(v => Pure(fn(v)));
    

    public static F<S> Read<S>()
        => new Tags.Read<S>();

    public static F<V> ReadMap<S, V>(Func<S, V> fn)
        => Read<S>().Map(fn);

    public static F<V> ReadThen<S, V>(Func<S, F<V>> fn)
        => Read<S>().Then(fn);


    public static F<Nil> Write<W>(W newState)
        => new Tags.Write<W>(newState);

    public static F<Nil> ReadWrite<R, W>(Func<R, W> fn)
        => Read<R>().Then(s => Write(fn(s)));




    
    

    public static F<Nil> Say(string line)
        => new Tags.Say(line);

    public static F<string> Hear()
        => new Tags.Hear();

    
    public static F<Bind[]> InvokeRunner(Outline outline, Bind[] binds, string[] runFlags)
        => new Tags.InvokeRunner(outline, binds, runFlags);
    
    public static F<string[]> DredgeBindLog(string name)
        => new Tags.DredgeBindLog(name);

    public static F<Nil> AppendToBindLog(Bind bind)
        => new Tags.AppendToBindLog(bind);

    public static F<Nil> LoopThru<V, V2>(this F<IEnumerable<V>> through, Func<V, F<V2>> @do)
        => through.Then(els => 
            els.Aggregate(Pure(default(V2)), (ac, el) => @do(el))
            .Then(_ => Id()));

    public static F<Nil> LoopThru<V, V2>(this IEnumerable<F<V>> through, Func<V, F<V2>> @do)
        => through
            .Aggregate(Pure(default(V2)), (ac, el) => el.Then(@do)) //?????!?!?!
            .Then(_ => Id());

    // public static M<AR, AW> LoopThru<AR, AW, El>(this M<AR, AW, IEnumerable<El>> io,
    //     Func<M<AW, AW>, El, M<AW, AW>> @do)
    //     => io.Then((x, els) => x.LoopThru(els, @do));

    
    public static F<V> When<V>(F<bool> @if, F<V> @then, F<V> @else)
        => @if.Then(result => result ? then : @else);
    
    public static F<V> When<V>(F<bool> @if, F<V> @then)
        => @if.Then(result => result ? then : Pure(default(V)!));
    
    // public static M<R, BW, BV> When<R, W, AR, AW, BR, BW, BV>(this M<R, W> io, M<AR, AW, bool> @if, M<BR, BW, BV> @then, M<BR, BW, BV> @else)
    //     where W : AR
    //     where AW : BR
    //     => io.Then(_ => @if).Then((_, result) => result ? then : @else);
    //
    // public static M<R, S> When<R, W, S>(this M<R, W> io, M<S, S, bool> @if, M<S, S> @then)
    //     where W : S
    //     => io.Then(_ => @if).Then((x, result) => result ? then : x);
}


public abstract record Tags
{
    public record Id : F<Nil>;
    public record Pure<V>(V val) : F<V>;
    public record FMap<AV, BV>(F<AV> io, Func<AV, F<BV>> fn) : F<BV>;

    public record Read<R> : F<R>;
    public record Write<W>(W val) : F<Nil>;

    public record Say(string Line) : F<Nil>;
    public record Hear : F<string>;

    public record InvokeRunner(Outline Outline, Bind[] Binds, string[] RunFlags) : F<Bind[]>;
    
    public record DredgeBindLog(string Name) : F<string[]>;
    public record AppendToBindLog(Bind bind) : F<Nil>;
}