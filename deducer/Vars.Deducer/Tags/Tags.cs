using Vars.Deducer.Model;

namespace Vars.Deducer.Tags;

public interface M<in R, out W> {}
public interface M<in R, out W, out V> : M<R, W> {}

public interface F<out V> {}

public struct Nil {}

public abstract record Tags
{
    public record Id : F<Nil>;
    public record Pure<V>(V val) : F<V>;
    public record Bind<AV, BV>(F<AV> io, Func<AV, F<BV>> fn) : F<BV>;

    public record Read<R> : F<R>;
    public record Write<W>(W val) : F<Nil>;
}

public abstract class CoreTags
{
    public record Say(string Line) : F<Nil>;
    public record Hear : F<string>;
}

public abstract class DeducerTags
{
    public record GetUserPins(string[] Names) : F<Bind[]>;
    
    public record InvokeRunner(Outline Outline, Bind[] Binds, string[] RunFlags) : F<Bind[]>;
    
    public record PickValue(string Name, string[] Values) : F<string?>;
    
    public record DredgeBindLog(string Name) : F<string[]>;
    public record AppendToBindLog(Bind bind) : F<Nil>;
}

public static class DeducerOps
{
    public static DeducerTags.PickValue PickValue(string name, string[] options) => new(name, options);
}