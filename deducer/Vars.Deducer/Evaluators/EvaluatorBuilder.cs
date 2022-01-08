using System.Collections.Immutable;

namespace Vars.Deducer.Evaluators;

public record EvaluatorBuilder<X>(ImmutableList<Func<IEvaluator<X>, IEvaluator<X>>> EvalFacs) : EvaluatorBuilder
{
    public IEvaluator<X> Build() => new RootEvaluator<X>(EvalFacs);
}

public abstract record EvaluatorBuilder
{
    public static EvaluatorBuilder<X> WithContext<X>()
        => new(ImmutableList<Func<IEvaluator<X>, IEvaluator<X>>>.Empty);
}