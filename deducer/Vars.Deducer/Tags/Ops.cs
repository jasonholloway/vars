using Vars.Deducer.Model;

namespace Vars.Deducer.Tags;

using static Tags;
using static CoreTags;
using static DeducerTags;

public static class Ops
{
    public static F<V> Pure<V>(V val)
        => new Pure<V>(val);
    
    public static F<Nil> Id()
        => new Id();
    
    
    public static F<BV> Then<AV, BV>(this F<AV> io, Func<AV, F<BV>> fn)
        => new Bind<AV, BV>(io, fn);
    
    public static F<BV> Then<AV, BV>(this F<AV> io, Func<F<BV>> fn)
        => new Bind<AV, BV>(io, _ => fn());
    
    public static F<BV> Then<AV, BV>(this F<AV> io, F<BV> next)
        => new Bind<AV, BV>(io, _ => next);
    
    
    public static F<BV> Map<AV, BV>(this F<AV> io, Func<AV, BV> fn)
        => io.Then(v => Pure(fn(v)));
    

    public static F<S> Read<S>()
        => new Read<S>();

    public static F<V> ReadMap<S, V>(Func<S, V> fn)
        => Read<S>().Map(fn);

    public static F<V> ReadThen<S, V>(Func<S, F<V>> fn)
        => Read<S>().Then(fn);


    public static F<Nil> Write<W>(W newState)
        => new Write<W>(newState);

    public static F<Nil> ReadWrite<R, W>(Func<R, W> fn)
        => Read<R>().Then(s => Write(fn(s)));




    
    

    public static F<Nil> Say(string line)
        => new Say(line);

    public static F<string> Hear()
        => new Hear();

    
    public static F<Bind[]> InvokeRunner(Outline outline, Bind[] binds, string[] runFlags)
        => new InvokeRunner(outline, binds, runFlags);
    
    public static F<string[]> DredgeBindLog(string name)
        => new DredgeBindLog(name);

    public static F<Nil> AppendToBindLog(Bind bind)
        => new AppendToBindLog(bind);

    public static F<Nil> LoopThru<V, V2>(this F<IEnumerable<V>> through, Func<V, F<V2>> @do)
        => through.Then(els => 
            els.Aggregate(Pure(default(V2)), (ac, el) => ac.Then(@do(el)))
                .Then(_ => Id()));

    public static F<Nil> LoopThru<V, V2>(this IEnumerable<F<V>> through, Func<V, F<V2>> @do)
        => through
            .Aggregate(Pure(default(V2)), (ac, el) => ac.Then(el.Then(@do)))
            .Then(_ => Id());

    // public static M<AR, AW> LoopThru<AR, AW, El>(this M<AR, AW, IEnumerable<El>> io,
    //     Func<M<AW, AW>, El, M<AW, AW>> @do)
    //     => io.Then((x, els) => x.LoopThru(els, @do));

    
    public static F<V> When<V>(F<bool> @if, F<V> @then, F<V> @else)
        => @if.Then(result => result ? then : @else);
    
    public static F<V> When<V>(F<bool> @if, F<V> @then)
        => @if.Then(result => result ? then : Pure(default(V)!));

    public static F<V> Do<V>(F<V> fv)
        => fv;
    
    public static F<V> Do<V>(Func<F<V>> f)
        => f();

    public static F<BV> Do<AV, BV>(F<AV> f, Func<AV, F<BV>> af)
        => f.Then(af);
    
    public static F<CV> Do<AV, BV, CV>(F<AV> f, Func<AV, F<BV>> af, Func<BV, F<CV>> bf)
        => f.Then(af).Then(bf);
    
    public static F<DV> Do<AV, BV, CV, DV>(F<AV> f, Func<AV, F<BV>> af, Func<BV, F<CV>> bf, Func<CV, F<DV>> cf)
        => f.Then(af).Then(bf).Then(cf);
    
    public static F<EV> Do<AV, BV, CV, DV, EV>(F<AV> f, Func<AV, F<BV>> af, Func<BV, F<CV>> bf, Func<CV, F<DV>> cf, Func<DV, F<EV>> df)
        => f.Then(af).Then(bf).Then(cf).Then(df);
    
    public static F<FV> Do<AV, BV, CV, DV, EV, FV>(F<AV> f, Func<AV, F<BV>> af, Func<BV, F<CV>> bf, Func<CV, F<DV>> cf, Func<DV, F<EV>> df, Func<EV, F<FV>> ef)
        => f.Then(af).Then(bf).Then(cf).Then(df).Then(ef);
    
    public static F<GV> Do<AV, BV, CV, DV, EV, FV, GV>(F<AV> f, Func<AV, F<BV>> af, Func<BV, F<CV>> bf, Func<CV, F<DV>> cf, Func<DV, F<EV>> df, Func<EV, F<FV>> ef, Func<FV, F<GV>> ff)
        => f.Then(af).Then(bf).Then(cf).Then(df).Then(ef).Then(ff);

    // public static M<R, BW, BV> When<R, W, AR, AW, BR, BW, BV>(this M<R, W> io, M<AR, AW, bool> @if, M<BR, BW, BV> @then, M<BR, BW, BV> @else)
    //     where W : AR
    //     where AW : BR
    //     => io.Then(_ => @if).Then((_, result) => result ? then : @else);
    //
    // public static M<R, S> When<R, W, S>(this M<R, W> io, M<S, S, bool> @if, M<S, S> @then)
    //     where W : S
    //     => io.Then(_ => @if).Then((x, result) => result ? then : x);
}
