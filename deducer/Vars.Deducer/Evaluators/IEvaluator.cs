using Vars.Deducer.Tags;

namespace Vars.Deducer.Evaluators;

public interface IEvaluator<X>
{
    Tag Eval(X x, Tag tag);
}