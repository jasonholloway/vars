using System.Linq;
using NUnit.Framework;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
    public class PlannerTests
    {
        [Test]
        public void Plans()
        {
            var index = TestHelpers.Outlines(
                "file4;C;field,farm;flour;",
                "file1;A;eggs,flour;cake;",
                "file2;D;farm;chicken;",
                "file3;B;chicken,flour;eggs;"
            );

            var plan = Planner.Plan(index, new VarTarget(new Var("cake")));
            TestContext.WriteLine(plan.ToString());

            Assert.That(
                plan.Roots.OfType<Plan.BlockNode>().Select(u => u.Outline).First().ToString(),
                Is.EqualTo("file1;A;eggs,flour;cake;"));
        }
    }

    public static class NodeExtensions
    {
        public static TNode As<TNode>(this Node node) where TNode : Node
            => (TNode)node;

    }
}