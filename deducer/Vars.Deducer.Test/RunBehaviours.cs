using System;
using System.Collections.Immutable;
using System.Linq;
using Vars.Deducer.Evaluators;
using Vars.Deducer.Tags;

namespace Vars.Deducer.Test
{
    public record RunBehaviour(string Bid, Bind[] Binds);
    
    public static class RunBehaviourExtensions
    {
        public static EvaluatorBuilder<X> AddRunBehaviours<X>(this EvaluatorBuilder<X> builder, params RunBehaviour[] behaviours)
            => new(builder.EvalFacs.Add(root => new RunBehaviourEvaluator<X>(root, behaviours)));
        
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

        public RunBehaviourEvaluator(IEvaluator<X> root, RunBehaviour[] behaviours) : base(root)
        {
            _lookup = behaviours.ToLookup(t => t.Bid);
        }

        public Cont<X, Bind[]> Match(X x, DeducerTags.InvokeRunner tag)
        {
            if (x is IState<X, ImmutableArray<RunBehaviour>> state)
            {
                var matched = _lookup[tag.Outline.Bid];

                return new Return<X, Bind[]>(
                    state.Put(matched.ToImmutableArray()),
                    _lookup[tag.Outline.Bid].SelectMany(r => r.Binds).ToArray()
                );
            }
            
            throw new NotImplementedException($"Context doesn't implement {typeof(IState<X, ImmutableArray<RunBehaviour>>)}");
        }
    }
}