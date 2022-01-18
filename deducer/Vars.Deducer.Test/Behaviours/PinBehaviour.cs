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
            => new(builder.EvalFacs.Add(root => new UserPinBehaviourEvaluator<X>(root, behaviours)));

        public static EvaluatorBuilder<X> AddUserPinBehaviours<X>(this EvaluatorBuilder<X> builder, params (string Name, string Val)[] pins)
            => builder.AddUserPinBehaviours(
                pins.Select(b => new PinBehaviour(b.Name, b.Val)).ToArray()
            );
    }

    public class UserPinBehaviourEvaluator<X> : EvaluatorBase<X>
    {
        readonly ILookup<string, PinBehaviour> _lookup;

        public UserPinBehaviourEvaluator(IEvaluator<X> root, PinBehaviour[] behaviours) : base(root)
        {
            _lookup = behaviours.ToLookup(t => t.Name);
        }

        public F<Bind[]> Match(X x, DeducerTags.GetUserPins tag)
        {
            var matched = tag.Names
                .SelectMany(n => _lookup[n].TakeLast(1));

            return Write(matched.ToArray())
                .Map(_ => matched.Select(b => new Bind(b.Name, b.Val)).ToArray());
        }
    }
}