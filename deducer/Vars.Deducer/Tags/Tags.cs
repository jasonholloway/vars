using Vars.Deducer.Model;

namespace Vars.Deducer.Tags;

public interface M<in R, out W> {}
public interface M<in R, out W, out V> : M<R, W> {}

public interface F<out V> {}
public abstract record Tag<V> : F<V> {}

public struct Nil {}

public abstract record Tags
{
    public record Id : Tag<Nil>;
    public record Pure<V>(V val) : Tag<V>;
    public record Bind<AV, BV>(F<AV> io, Func<AV, F<BV>> fn) : Tag<BV>;

    public record Read<R> : Tag<R>;
    public record Write<W>(W val) : Tag<Nil>;
}

public abstract class CoreTags
{
    public record Say(string Line) : Tag<Nil>;
    public record Hear : Tag<string>;
}

public abstract class DeducerTags
{
    public record GetUserPins(string[] Names) : Tag<Bind[]>;
    
    public record InvokeRunner(Outline Outline, Bind[] Binds, string[] RunFlags) : Tag<Bind[]>;
    
    public record PickValue(string Name, string[] Values) : Tag<string?>;
    
    public record DredgeBindLog(string Name) : Tag<string[]>;
    public record AppendToBindLog(Bind bind) : Tag<Nil>;
}

public static class DeducerOps
{
    public static DeducerTags.PickValue PickValue(string name, string[] options) => new(name, options);
}