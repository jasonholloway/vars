using Vars.Deducer.Model;

namespace Vars.Deducer.Tags;

using static Tags;
using static CoreTags;
using static DeducerTags;

public static class Ops
{
    public static Tag<V> Pure<V>(V val)
        => new Pure<V>(val);
    
    public static Tag<Nil> Id()
        => new Id();
    
    
    public static Tag<BV> Then<AV, BV>(this Tag<AV> io, Func<AV, Tag<BV>> fn)
        => new Bind<AV, BV>(io, fn);
    
    public static Tag<BV> Then<AV, BV>(this Tag<AV> io, Func<Tag<BV>> fn)
        => new Bind<AV, BV>(io, _ => fn());
    
    public static Tag<BV> Then<AV, BV>(this Tag<AV> io, Tag<BV> next)
        => new Bind<AV, BV>(io, _ => next);
    
    
    public static Tag<BV> Map<AV, BV>(this Tag<AV> io, Func<AV, BV> fn)
        => io.Then(v => Pure(fn(v)));
    

    public static Tag<S> Read<S>()
        => new Read<S>();

    public static Tag<V> ReadMap<S, V>(Func<S, V> fn)
        => Read<S>().Map(fn);

    public static Tag<V> ReadThen<S, V>(Func<S, Tag<V>> fn)
        => Read<S>().Then(fn);


    public static Tag<Nil> Write<W>(W newState)
        => new Write<W>(newState);

    public static Tag<Nil> ReadWrite<R, W>(Func<R, W> fn)
        => Read<R>().Then(s => Write(fn(s)));



    


    public static Tag<Nil> Say(params string[] lines)
        => Pure(lines).LoopThru(line => new Say(line));

    public static Tag<string> Hear()
        => new Hear();
    
    public static Tag<(string?, string?)?> Hear2()
        => Hear()
            .Then(line => Pure<(string?, string?)?>(line != null ? Split2(line) : null));

    static (string?, string?) Split2(string? str)
    {
        var parts = str?.Split(" ", 2, StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries) ?? Array.Empty<string>();
        return (parts.ElementAtOrDefault(0), parts.ElementAtOrDefault(1));
    }
    
    
    public static Tag<Bind[]> InvokeRunner(Outline outline, Bind[] binds, string[] runFlags)
        => new InvokeRunner(outline, binds, runFlags);
    
    public static Tag<Bind[]> GetUserPins(params string[] names)
        => new GetUserPins(names);
    
    public static Tag<string[]> DredgeBindLog(string name)
        => new DredgeBindLog(name);

    public static Tag<Nil> AppendToBindLog(Bind bind)
        => new AppendToBindLog(bind);

    public static Tag<Nil> LoopThru<V, V2>(this Tag<IEnumerable<V>> through, Func<V, Tag<V2>> @do)
        => through.Then(els => 
            els.Aggregate(Pure(default(V2)), (ac, el) => ac.Then(@do(el)))
                .Then(_ => Id()));

    public static Tag<Nil> LoopThru<V, V2>(this IEnumerable<Tag<V>> through, Func<V, Tag<V2>> @do)
        => through
            .Aggregate(Pure(default(V2)), (ac, el) => ac.Then(el.Then(@do)))
            .Then(_ => Id());
    

    public static Tag<V> Gather<V>(V seed, Func<GatherOps<V>, V, Tag<LoopResult<V>>> loop)
        => GatherInner(Pure(new LoopResult<V>.Continue(seed)), loop);

    static Tag<V> GatherInner<V>(Tag<LoopResult<V>> prev, Func<GatherOps<V>, V, Tag<LoopResult<V>>> loop)
        => prev.Then(r => r switch
        {
            LoopResult<V>.Continue(var ac) => GatherInner(loop(new GatherOps<V>(), ac), loop),
            LoopResult<V>.End(var ac) => Pure(ac)
        });

    public class GatherOps<V>
    {
        public Tag<LoopResult<V>> Continue(V v) => Pure(new LoopResult<V>.Continue(v));
        public Tag<LoopResult<V>> End(V v) => Pure(new LoopResult<V>.End(v));
    }


    public static Tag<V> When<V>(Tag<bool> @if, Tag<V> @then, Tag<V> @else)
        => @if.Then(result => result ? then : @else);
    
    public static Tag<V> When<V>(Tag<bool> @if, Tag<V> @then)
        => @if.Then(result => result ? then : Pure(default(V)!));

    public static Tag<V> Do<V>(Tag<V> fv)
        => fv;
    
    public static Tag<V> Do<V>(Func<Tag<V>> f)
        => f();

    public static Tag<BV> Do<AV, BV>(Tag<AV> f, Func<AV, Tag<BV>> af)
        => f.Then(af);
    
    public static Tag<CV> Do<AV, BV, CV>(Tag<AV> f, Func<AV, Tag<BV>> af, Func<BV, Tag<CV>> bf)
        => f.Then(af).Then(bf);
    
    public static Tag<DV> Do<AV, BV, CV, DV>(Tag<AV> f, Func<AV, Tag<BV>> af, Func<BV, Tag<CV>> bf, Func<CV, Tag<DV>> cf)
        => f.Then(af).Then(bf).Then(cf);
    
    public static Tag<EV> Do<AV, BV, CV, DV, EV>(Tag<AV> f, Func<AV, Tag<BV>> af, Func<BV, Tag<CV>> bf, Func<CV, Tag<DV>> cf, Func<DV, Tag<EV>> df)
        => f.Then(af).Then(bf).Then(cf).Then(df);
    
    public static Tag<FV> Do<AV, BV, CV, DV, EV, FV>(Tag<AV> f, Func<AV, Tag<BV>> af, Func<BV, Tag<CV>> bf, Func<CV, Tag<DV>> cf, Func<DV, Tag<EV>> df, Func<EV, Tag<FV>> ef)
        => f.Then(af).Then(bf).Then(cf).Then(df).Then(ef);
    
    public static Tag<GV> Do<AV, BV, CV, DV, EV, FV, GV>(Tag<AV> f, Func<AV, Tag<BV>> af, Func<BV, Tag<CV>> bf, Func<CV, Tag<DV>> cf, Func<DV, Tag<EV>> df, Func<EV, Tag<FV>> ef, Func<FV, Tag<GV>> ff)
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

public abstract record LoopResult<V>
{
    public record Continue(V val) : LoopResult<V>;
    public record End(V val) : LoopResult<V>;
}
