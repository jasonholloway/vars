using System.Collections.Immutable;
using System.Linq;
using Vars.Deducer.Evaluators;
using Vars.Deducer.Tags;

namespace Vars.Deducer.Test.Behaviours
{
    using static Ops;
    
    public record RunBehaviour(string Bid, Bind[] Binds);
    
    public static class RunBehaviourExtensions
    {
        public static EvaluatorBuilder<X> AddRunBehaviours<X>(this EvaluatorBuilder<X> builder, params RunBehaviour[] behaviours)
            => new(builder.Evals.Add(new RunBehaviourEvaluator<X>(behaviours)));
        
        public static EvaluatorBuilder<X> AddRunBehaviours<X>(this EvaluatorBuilder<X> builder, params (string Bid, (string Key, string Val)[] Binds)[] behaviours)
            => builder.AddRunBehaviours(
                behaviours.Select(b => new RunBehaviour(
                    b.Bid, 
                    b.Binds.Select(t => new Bind(t.Key, t.Val)
                ).ToArray())
            ).ToArray());
    }

    public class RunBehaviourEvaluator<X> : EvaluatorBase<X>
    {
        readonly ILookup<string, RunBehaviour> _lookup;

        public RunBehaviourEvaluator(RunBehaviour[] behaviours)
        {
            _lookup = behaviours.ToLookup(t => t.Bid);
        }

        public Tag<Bind[]> Match(X x, DeducerTags.InvokeRunner tag)
        {
            var matched = _lookup[tag.Outline.Bid];

            return Write(matched.ToImmutableArray())
                .Map(_ => _lookup[tag.Outline.Bid].SelectMany(r => r.Binds).ToArray());
        }
    }
}