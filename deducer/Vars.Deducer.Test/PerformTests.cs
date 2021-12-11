using System.Linq;
using NUnit.Framework;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
    using static TestHelpers;

    public class PerformTests
    {
        [Test]
        public void Performs()
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

            var env = Planner
                .Plan(index, new VarTarget(new Var("cake")))
                .Perform(runner);
            
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
}