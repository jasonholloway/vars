using System.Collections.Generic;
using System.Linq;
using Vars.Deducer.Evaluators;
using Vars.Deducer.Tags;

namespace Vars.Deducer.Test.Behaviours
{
    using static Ops;
    
    public record PinBehaviour(string Name, string Val);
    
    public static class PinBehaviourExtensions
    {
        public static EvaluatorBuilder<X> AddUserPinBehaviours<X>(this EvaluatorBuilder<X> builder, PinBehaviour[] behaviours)
            => new(builder.Evals.Add(new UserPinBehaviourEvaluator<X>(behaviours)));

        public static EvaluatorBuilder<X> AddUserPinBehaviours<X>(this EvaluatorBuilder<X> builder, params (string Name, string Val)[] pins)
            => builder.AddUserPinBehaviours(
                pins.Select(b => new PinBehaviour(b.Name, b.Val)).ToArray()
            );
    }

    public class UserPinBehaviourEvaluator<X> : EvaluatorBase<X>
    {
        readonly ILookup<string, PinBehaviour> _lookup;

        public UserPinBehaviourEvaluator(IEnumerable<PinBehaviour> behaviours)
        {
            _lookup = behaviours.ToLookup(t => t.Name);
        }

        public Tag<Bind[]> Match(X x, DeducerTags.GetUserPins tag)
        {
            var matched = tag.Names
                .SelectMany(n => _lookup[n].TakeLast(1));

            return Write(matched.ToArray())
                .Map(_ => matched.Select(b => new Bind(b.Name, b.Val)).ToArray());
        }
    }
}