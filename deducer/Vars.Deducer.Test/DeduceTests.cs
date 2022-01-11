using System;
using System.Collections.Immutable;
using System.Linq;
using NUnit.Framework;
using Vars.Deducer.Evaluators;
using Vars.Deducer.Model;
using Vars.Deducer.Tags;
using Vars.Deducer.Test.Behaviours;

namespace Vars.Deducer.Test
{
    using static TestHelpers;
    
    //we want some pins as well
    //pins can be specified up front
    //which naturally works
    
    //and then they need to work through local bindings too
    //but maybe this is a bit much for now
    
    //todo the bind log
    //todo populate picks
    //seems to be running same blocks twice

    public class DeduceTests
    {
        [Test]
        public void Deduces()
        {
            var index = Outlines(
                "block4;C;field,farm;flour;",
                "block1;A;eggs,flour;cake;",
                "block2;D;farm;chicken;",
                "block3;B;chicken,flour;eggs;"
            );

            var prog = Planner
                .Plan(index, new VarTarget(new Var("cake")))
                .Deduce();

            var root = EvaluatorBuilder
                .WithContext<TestContext>()
                .AddCoreEvaluator()
                .AddUserPinBehaviours(
                    ("chicken", "Clucky")
                    )
                .AddRunBehaviours(
                     ("block1", new[] { ("cake", "Victoria Sponge") }),
                     ("block2", new[] { ("chicken", "Charles") }),
                     ("block3", new[] { ("eggs", "Medium") }),
                     ("block4", new[] { ("flour", "Self-Raising") })
                 )
                .AddPickBehaviours(
                    ("farm", "Windy Harbour"),
                    ("field", "Wheat1")
                    )
                .AddTestEvaluator()
                .Build();

            var state = root.Eval(TestContext.Empty, prog).Run(root).State;
            
            Assert.That(state.Env["chicken"].Value, Is.EqualTo("Clucky"));
            Assert.That(state.Env["flour"].Value, Is.EqualTo("Self-Raising"));
            Assert.That(state.Env["farm"].Value, Is.EqualTo("Windy Harbour"));
            Assert.That(state.Env["field"].Value, Is.EqualTo("Wheat1"));
            
            Assert.That(
                state.Runs.Select(b => b.Bid),
                Is.EqualTo(new[]
                {
                    "block4",
                    "block3",
                    "block1"
                }));
        }
    }
    
    public static class TestEvaluatorExtensions
    {
        public static EvaluatorBuilder<X> AddTestEvaluator<X>(this EvaluatorBuilder<X> builder)
            => new(builder.EvalFacs.Add(root => new TestEvaluator<X>(root)));
    }

    public class TestEvaluator<X> : EvaluatorBase<X>
    {
        public TestEvaluator(IEvaluator<X> root) : base(root)
        { }

        public Cont<X, string[]> Match(X x, DeducerTags.DredgeBindLog tag)
            => new Return<X, string[]>(x, new[] { "woof" });

        public Cont<X, Nil> Match(X x, DeducerTags.AppendToBindLog tag)
            => new Return<X, Nil>(x, default);
        
        public Cont<X, string> Match(X x, CoreTags.Hear _)
            => new Return<X, string>(x, "HELLO!");
        
        public Cont<X, Nil> Match(X x, CoreTags.Say _)
            => new Return<X, Nil>(x, default);
    }
    
    
    public record TestContext(Env Env, RunContext Run, ImmutableArray<RunBehaviour> Runs, (string, PickBehaviour?)[] Picks, PinBehaviour[] Pins) 
          : IState<TestContext, Env>, 
            IState<TestContext, RunContext>, 
            IState<TestContext, ImmutableArray<RunBehaviour>>,
            IState<TestContext, (string, PickBehaviour?)[]>,
            IState<TestContext, PinBehaviour[]>
    {
        public static readonly TestContext Empty = new(Env.Empty, null!, ImmutableArray<RunBehaviour>.Empty, Array.Empty<(string, PickBehaviour?)>(), Array.Empty<PinBehaviour>());

        Env IState<TestContext, Env>.Get() => Env;

        (string, PickBehaviour?)[] IState<TestContext, (string, PickBehaviour?)[]>.Zero => Array.Empty<(string, PickBehaviour?)>();

        (string, PickBehaviour?)[] IState<TestContext, (string, PickBehaviour?)[]>.Combine(
            (string, PickBehaviour?)[] left, (string, PickBehaviour?)[] right)
            => left.Concat(right).ToArray();

        TestContext IState<TestContext, (string, PickBehaviour?)[]>.Put((string, PickBehaviour?)[] state)
            => this with { Picks = ((IState<TestContext, (string, PickBehaviour?)[]>)(this)).Combine(Picks, state) };
        
        (string, PickBehaviour?)[] IState<TestContext, (string, PickBehaviour?)[]>.Get() => Picks;

        RunContext IState<TestContext, RunContext>.Get() => Run;

        TestContext IState<TestContext, RunContext>.Put(RunContext run) => this with { Run = run };
        TestContext IState<TestContext, Env>.Put(Env env)  => this with { Env = env };

        Env IState<TestContext, Env>.Zero => Env.Empty;
        Env IState<TestContext, Env>.Combine(Env left, Env right)
        {
            throw new NotImplementedException();
        }

        RunContext IState<TestContext, RunContext>.Zero => null!;
        RunContext IState<TestContext, RunContext>.Combine(RunContext left, RunContext right)
        {
            throw new NotImplementedException();
        }
        
        ImmutableArray<RunBehaviour> IState<TestContext, ImmutableArray<RunBehaviour>>.Zero => ImmutableArray<RunBehaviour>.Empty;
        ImmutableArray<RunBehaviour> IState<TestContext, ImmutableArray<RunBehaviour>>.Get() => Runs;
        TestContext IState<TestContext, ImmutableArray<RunBehaviour>>.Put(ImmutableArray<RunBehaviour> state) => this with { Runs = Runs.AddRange(state) };
        ImmutableArray<RunBehaviour> IState<TestContext, ImmutableArray<RunBehaviour>>.Combine(ImmutableArray<RunBehaviour> left, ImmutableArray<RunBehaviour> right)
        {
            throw new NotImplementedException();
        }
        

        TestContext IState<TestContext, PinBehaviour[]>.Put(PinBehaviour[] state) => this with
        {
            Pins = ((IState<TestContext, PinBehaviour[]>)this).Combine(Pins, state)
        };

        PinBehaviour[] IState<TestContext, PinBehaviour[]>.Zero => Array.Empty<PinBehaviour>();
        PinBehaviour[] IState<TestContext, PinBehaviour[]>.Combine(PinBehaviour[] left, PinBehaviour[] right) => left.Concat(right).ToArray();
        PinBehaviour[] IState<TestContext, PinBehaviour[]>.Get() => Pins;
    }
}