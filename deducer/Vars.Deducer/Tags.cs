namespace Vars.Deducer;

public interface IO {}
public interface IO<out T> : IO {}

public static class Ops
{
    public static IO<T> Lift<T>(T val)
        => new Tags.Lift<T>(val);

    public static IO Id()
        => new Tags.Id();

    public static IO<T2> Bind<T1, T2>(IO<T1> io, Func<T1, IO<T2>> fn)
        => new Tags.Bind<T1, T2>(io, fn);


    public static IO<Env> Read()
        => throw new NotImplementedException();

    public static IO<T> Read<T>(Func<Env, T> fn)
        => Read().Then(e => Lift(fn(e)));

    public static IO<Env> Write(Env env)
        => throw new NotImplementedException();

    public static IO<Env> Update(Func<Env, Env> fn)
        => Read().Then(e => Write(fn(e)));
    

    public static IO<Nil> Say(string line)
        => new Tags.Say(line);

    public static IO<string> Hear()
        => new Tags.Hear();
    
    public static IO<TAc> ForEach<TEl, TAc>(IEnumerable<TEl> els, Func<TEl, IO<TAc>> fn)
        => els.Aggregate(Lift(default(TAc)), (io, el) => io.Then(fn(el)));
    
    public static IO ForEach<TEl>(IEnumerable<TEl> els, Func<TEl, IO> fn)
        => els.Aggregate(Id(), (io, el) => io.Then(fn(el)));


    public static IO<T> When<T>(IO<bool> @if, IO<T> success, IO<T> fail)
        => @if.Then(result => result ? success : fail);
    
    public static IO When(IO<bool> @if, IO then, IO @else)
        => @if.Then(result => result ? then : @else);
}



public abstract record Tags
{
    public record Id : IO;
    public record Lift<T>(T val) : IO<T>;
    public record Bind<T1, T2>(IO<T1> io, Func<T1, IO<T2>> fn) : IO<T2>;

    public record Say(string Line) : IO<Nil>;
    public record Hear : IO<string>;
    
}

public static class IOExtensions
{
    public static IO<T2> Then<T1, T2>(this IO<T1> io, Func<T1, IO<T2>> fn)
        => new Tags.Bind<T1, T2>(io, fn);
    
    public static IO Then<T1>(this IO<T1> io, Func<T1, IO> fn)
        => new Tags.Bind<T1, Nil>(io, v => fn(v).Then(Ops.Lift(default(Nil))));

    public static IO<T2> Then<T1, T2>(this IO<T1> io, IO<T2> io2)
        => io.Then(_ => io2);
    
    
    public static IO<T> Then<T>(this IO io, Func<IO<T>> fn)
        => throw new NotImplementedException();

    public static IO<T> Then<T>(this IO io, IO<T> io2)
        => throw new NotImplementedException();
    
    public static IO Then(this IO io, IO io2)
        => throw new NotImplementedException();
    
    
    // public static IO<T2?> When<T1, T2>(this IO<T1> io, Predicate<T1> predicate)
    //     => io.Then(v => predicate(v) ?   )
    
    
}

public struct Nil {}