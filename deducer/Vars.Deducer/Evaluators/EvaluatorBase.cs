using Vars.Deducer.Tags;

namespace Vars.Deducer.Evaluators;

public abstract class EvaluatorBase<X> : IEvaluator<X>
{
    public Tag Eval(X x, Tag tag)
        => ((dynamic)this).Match(x, (dynamic)tag);
    
    protected Tag Match(X x, Tag m) => m!;
}