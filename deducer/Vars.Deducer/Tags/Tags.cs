using Vars.Deducer.Model;

namespace Vars.Deducer.Tags;

public interface Tag {}
public interface Tag<out V> : Tag {}



public interface TagVisitor
{
    void Visit(Tags.Id tag);
    void Visit<V>(Tags.Pure<V> tag);
    void Visit<AV, BV>(Tags.Bind<AV, BV> tag);
    void Visit<R>(Tags.Read<R> tag);
    void Visit<W>(Tags.Write<W> tag);
}


public interface VisitableTag
{
    public void Receive<Visitor>(Visitor visitor)
        where Visitor : TagVisitor;
}


public struct Nil {}

public abstract record Tags
{
    public record Id : Tag<Nil>, VisitableTag
    {
        public void Receive<Visitor>(Visitor visitor) where Visitor : TagVisitor
            => visitor.Visit(this);
    };

    public record Pure<V>(V val) : Tag<V>, VisitableTag
    {
        public void Receive<Visitor>(Visitor visitor) where Visitor : TagVisitor
            => visitor.Visit(this);
    }

    public record Bind<AV, BV>(Tag<AV> io, Func<AV, Tag<BV>> fn) : Tag<BV>, VisitableTag
    {
        public void Receive<Visitor>(Visitor visitor) where Visitor : TagVisitor
            => visitor.Visit(this);
    }

    public record Read<R> : Tag<R>, VisitableTag
    {
        public void Receive<Visitor>(Visitor visitor) where Visitor : TagVisitor
            => visitor.Visit(this);
    }

    public record Write<W>(W val) : Tag<Nil>, VisitableTag
    {
        public void Receive<Visitor>(Visitor visitor) where Visitor : TagVisitor
            => visitor.Visit(this);
    }
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