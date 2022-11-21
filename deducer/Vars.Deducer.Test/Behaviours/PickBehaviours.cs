using System.Collections.Generic;
using System.Linq;
using Vars.Deducer.Evaluators;
using Vars.Deducer.Tags;

namespace Vars.Deducer.Test.Behaviours
{
    using static Ops;
    
    public record PickBehaviour(string Name, string Val);
    
    public static class PickBehaviourExtensions
    {
        public static EvaluatorBuilder<X> AddPickBehaviours<X>(this EvaluatorBuilder<X> builder, PickBehaviour[] behaviours)
            => new(builder.Evals.Add(new PickBehaviourEvaluator<X>(behaviours)));

        public static EvaluatorBuilder<X> AddPickBehaviours<X>(this EvaluatorBuilder<X> builder, params (string Name, string Val)[] behaviours)
            => builder.AddPickBehaviours(
                behaviours.Select(b => new PickBehaviour(b.Name, b.Val)).ToArray()
            );
    }

    public class PickBehaviourEvaluator<X> : EvaluatorBase<X>
    {
        readonly ILookup<string, PickBehaviour> _lookup;

        public PickBehaviourEvaluator(IEnumerable<PickBehaviour> behaviours)
        {
            _lookup = behaviours.ToLookup(t => t.Name);
        }

        public Tag<string?> Match(X x, DeducerTags.PickValue tag)
        {
            var matched = _lookup[tag.Name].FirstOrDefault();

            return Write(new[] { (tag.Name, matched) })
                .Map(_ => matched?.Val);
        }
    }
}