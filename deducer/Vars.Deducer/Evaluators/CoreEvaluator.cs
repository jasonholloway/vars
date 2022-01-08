using Vars.Deducer.Tags;

namespace Vars.Deducer.Evaluators;

public static class CoreEvaluatorExtensions
{
    public static EvaluatorBuilder<X> AddCoreEvaluator<X>(this EvaluatorBuilder<X> builder) 
        => new(builder.EvalFacs.Add(root => new CoreEvaluator<X>(root)));
}

public class CoreEvaluator<X> : EvaluatorBase<X>
{
    public CoreEvaluator(IEvaluator<X> root) 
        : base(root) {}
    
    public Cont<X, Nil> Match(X x, Tags.Tags.Id _)
        => new Return<X, Nil>(x, default);

    public Cont<X, V> Match<V>(X x, Tags.Tags.Pure<V> tag)
        => new Return<X, V>(x, tag.val);


    public Cont<X, BV> Match<AV, BV>(X x, Tags.Tags.Bind<AV, BV> tag)
        => _root.Eval(x, tag.io)
            .FlatMap((x2, av) => _root.Eval(x2, tag.fn(av)));


    public Cont<X, R> Match<R>(X x, Tags.Tags.Read<R> tag)
        => x is IState<X, R> state
            ? new Return<X, R>(x, state.Get())
            : throw new NotImplementedException($"Context doesn't implement {typeof(IState<X, R>)}");
    
    public Cont<X, Nil> Match<W>(X x, Tags.Tags.Write<W> tag)
        => x is IState<X, W> state
            ? new Return<X, Nil>(state.Put(tag.val), default)
            : throw new NotImplementedException($"Context doesn't implement {typeof(IState<X, W>)}");
}