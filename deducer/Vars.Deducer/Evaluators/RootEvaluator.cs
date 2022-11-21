using Vars.Deducer.Tags;

namespace Vars.Deducer.Evaluators;

public class RootEvaluator<X> : IEvaluator<X>
{
    IEvaluator<X>[] _evals;

    public RootEvaluator(IEnumerable<IEvaluator<X>> evals)
    {
        _evals = evals.ToArray();
    }

    public RootEvaluator(params IEvaluator<X>[] evals) : this(evals.AsEnumerable()) 
    {}

    public Tag Eval(X x, Tag tag)
        => _evals.Aggregate(tag, (t, eval) => eval.Eval(x, t));
}