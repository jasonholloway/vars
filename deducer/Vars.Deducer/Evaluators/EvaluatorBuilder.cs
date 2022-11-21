using System.Collections.Immutable;

namespace Vars.Deducer.Evaluators;

public record EvaluatorBuilder<X>(ImmutableList<IEvaluator<X>> Evals) : EvaluatorBuilder
{
    public IEvaluator<X> Build() => new RootEvaluator<X>(Evals);
}

public abstract record EvaluatorBuilder
{
    public static EvaluatorBuilder<X> WithContext<X>()
        => new(ImmutableList<IEvaluator<X>>.Empty);
}