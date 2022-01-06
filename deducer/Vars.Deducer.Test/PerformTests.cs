using System;
using System.Linq;
using System.Threading.Tasks;
using NUnit.Framework;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
    using static TestHelpers;

    public class PerformTests
    {
        [Test]
        public async Task Performs()
        {
            var runner = Blocks(
                ("block1", new[] { ("cake", "Victoria Sponge") }),
                ("block2", new[] { ("chicken", "Charles") }),
                ("block3", new[] { ("eggs", "Medium") }),
                ("block4", new[] { ("flour", "Self-Raising") })
            );

            var index = Outlines(
                "block4;C;field,farm;flour;",
                "block1;A;eggs,flour;cake;",
                "block2;D;farm;chicken;",
                "block3;B;chicken,flour;eggs;"
            );

            var prog = Planner
                .Plan(index, new VarTarget(new Var("cake")))
                .Perform();

            var root = EvaluatorBuilder
                .WithContext<PerformContext>()
                .AddCoreEvaluator()
                .AddTestEvaluator()
                .Build();

            var env = root.Eval(PerformContext.Empty, prog).Run(root).State.Env;

            Assert.That(runner.CalledBids.ToArray(),
                Is.EqualTo(new[]
                {
                    "block2",
                    "block4",
                    "block3",
                    "block1"
                }));

            Assert.That(env["chicken"].Value, Is.EqualTo("Charles"));
            Assert.That(env["flour"].Value, Is.EqualTo("Self-Raising"));
        }
    }
    
    public static class TestEvaluatorExtensions
    {
        public static EvaluatorBuilder<X> AddTestEvaluator<X>(this EvaluatorBuilder<X> builder) 
            => new(builder.EvalFacs.Add(root => new TestEvaluator<X>(root)));
    }

    public class TestEvaluator<X> : Evaluator<X>
    {
        public TestEvaluator(IEvaluator<X> root) : base(root)
        { }

        public Cont<X, string[]> Match(X x, Tags.DredgeBindLog tag)
            => new Return<X, string[]>(x, new[] { "woof" });

        public Cont<X, Nil> Match(X x, Tags.AppendToBindLog tag)
            => new Return<X, Nil>(x, default);
        
        public Cont<X, string> Match(X x, Tags.Hear _)
            => new Return<X, string>(x, "HELLO!");
        
        public Cont<X, Nil> Match(X x, Tags.Say _)
            => new Return<X, Nil>(x, default);
        
        public Cont<X, Bind[]> Match(X x, Tags.InvokeRunner _)
            => new Return<X, Bind[]>(x, Array.Empty<Bind>());
    }
    
    public record PerformContext(Env Env, RunContext Run) : IState<PerformContext, Env> , IState<PerformContext, RunContext>
    {
        public static readonly PerformContext Empty = new(Env.Empty, null!);
        
        Env IState<PerformContext, Env>.Get() => Env;
        RunContext IState<PerformContext, RunContext>.Get() => Run;

        PerformContext IState<PerformContext, RunContext>.Put(RunContext run) => this with { Run = run };
        PerformContext IState<PerformContext, Env>.Put(Env env)  => this with { Env = env };
        
        Env IState<PerformContext, Env>.Zero => Env.Empty;
        Env IState<PerformContext, Env>.Combine(Env left, Env right)
        {
            throw new NotImplementedException();
        }

        RunContext IState<PerformContext, RunContext>.Zero => null!;
        RunContext IState<PerformContext, RunContext>.Combine(RunContext left, RunContext right)
        {
            throw new NotImplementedException();
        }
    }
}