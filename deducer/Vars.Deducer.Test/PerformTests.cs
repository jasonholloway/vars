using System;
using System.Linq;
using System.Threading;
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
                .Perform(runner);


            var (env, _) = await Run(prog);


            ValueTask<(Env, Nil)> Run(M<Env, Env> m)
            {
                var root = new RootEvaluator(
                    r => new CoreEvaluator(r),
                    r => new TestEvaluator(r)
                );
                
                return root.Eval(Env.Empty, m).ToTask(root);
            }

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

    public class TestEvaluator : Evaluator
    {
        public TestEvaluator(IEvaluator root) : base(root)
        { }

        public Cont<S, string[]> Match<S>(S state, Tags.DredgeBindLog<S> tag)
            => new Return<S, string[]>(state, new[] { "woof" });

        public Cont<S, Nil> Match<S>(S state, Tags.AppendToBindLog<S> tag)
            => new Return<S, Nil>(state, default);
        
        public Cont<S, string> Match<S>(S state, Tags.Hear<S> _)
            => new Return<S, string>(state, "HELLO!");
        
        public Cont<R, Nil> Match<R, W>(R state, Tags.Say<R, W> _)
            => new Return<R, Nil>(state, default);
        
        public Cont<R, Bind[]> Match<R, W>(R state, Tags.InvokeRunner<R, W> _)
            => new Return<R, Bind[]>(state, Array.Empty<Bind>());
    }
}