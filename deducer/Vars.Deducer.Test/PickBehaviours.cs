using System;
using System.Collections.Immutable;
using System.Linq;
using Vars.Deducer.Evaluators;
using Vars.Deducer.Tags;

namespace Vars.Deducer.Test
{
    public record PickBehaviour(string Name, string Val);
    
    public static class PickBehaviourExtensions
    {
        public static EvaluatorBuilder<X> AddPickBehaviours<X>(this EvaluatorBuilder<X> builder, PickBehaviour[] behaviours)
            => new(builder.EvalFacs.Add(root => new PickBehaviourEvaluator<X>(root, behaviours)));

        public static EvaluatorBuilder<X> AddPickBehaviours<X>(this EvaluatorBuilder<X> builder, params (string Name, string Val)[] behaviours)
            => builder.AddPickBehaviours(
                behaviours.Select(b => new PickBehaviour(b.Name, b.Val)).ToArray()
            );
    }

    public class PickBehaviourEvaluator<X> : EvaluatorBase<X>
    {
        readonly ILookup<string, PickBehaviour> _lookup;

        public PickBehaviourEvaluator(IEvaluator<X> root, PickBehaviour[] behaviours) : base(root)
        {
            _lookup = behaviours.ToLookup(t => t.Name);
        }

        public Cont<X, string?> Match(X x, DeducerTags.PickValue tag)
        {
            if (x is IState<X, (string, PickBehaviour?)[]> state)
            {
                var matched = _lookup[tag.Name].FirstOrDefault();

                return new Return<X, string?>(
                    state.Put(new[] { (tag.Name, matched) }),
                    matched?.Val
                );
            }
            
            throw new NotImplementedException($"Context doesn't implement {typeof(IState<X, ImmutableArray<RunBehaviour>>)}");
        }
    }
}