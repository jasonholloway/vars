using System.Linq;
using NUnit.Framework;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
    using static TestHelpers;
    
    public class PlannerTests
    {
        [Test]
        public void Plans()
        {
            var index = Outlines(
                "file4;C;field,farm;flour;",
                "file1;A;eggs,flour;cake;",
                "file2;D;farm;chicken;",
                "file3;B;chicken,flour;eggs;"
            );

            var plan = Planner.Plan(index, new VarTarget(new Var("cake")));
            TestContext.WriteLine(plan.ToString());

            Assert.That(
                plan.Roots.Select(u => ((PlanNode.Block)(u.Node)).Outline).First().ToString(),
                Is.EqualTo("file1;A;eggs,flour;cake;"));
        }
        
        [Test]
        public void RoundsUpInputs()
        {
            var index = Outlines(
                "file4;C;field,farm;flour;",
                "file1;A;eggs,flour;cake;",
                "file2;D;farm;chicken;",
                "file3;B;chicken,flour;eggs;"
            );

            var plan = Planner
                .Plan(index, new VarTarget(new Var("cake")))
                .RoundUpInputs();
            
            TestContext.WriteLine(plan.ToString());

            Assert.That(
                plan.Node.AllInputs.Select(v => v.ToString()),
                Is.EquivalentTo(new[]
                {
                    "field", "farm", "eggs", "flour", "chicken"
                }));

            Assert.That(
                plan.Node.AllInputs,
                Does.Not.Contain(new Var("cake")));
        }
        
        [Test]
        public void RoundUpInputs_StripsPins()
        {
            var index = Outlines(
                "file4;C;field{crop=corn},farm;flour;",
                "file1;A;eggs,flour;cake;",
                "file2;D;farm{location=Cumbria};chicken;",
                "file3;B;chicken,flour;eggs;"
            );

            var plan = Planner
                .Plan(index, new VarTarget(new Var("cake")))
                .RoundUpInputs();

            Assert.That(
                plan.Node.AllInputs.Select(v => v.ToString()),
                Is.EquivalentTo(new[]
                {
                    "field", "farm", "eggs", "flour", "chicken"
                }));
        }
        
        [Test]
        public void ToExecutions()
        {
            var index = Outlines(
                "file4;C;field,farm;flour;",
                "file1;A;eggs,flour;cake;",
                "file2;D;farm;chicken;",
                "file3;B;chicken,flour;eggs;"
            );

            var exec = Planner
                .Plan(index, new VarTarget(new Var("cake")))
                .RoundUpInputs();
        }

        [Test]
        public void Hashes()
        {
            var v1 = new Var("moo");
            var v2 = new Var("moop".TrimEnd('p'));

            Assert.That(v1.GetHashCode(), Is.EqualTo(v2.GetHashCode()));
        }
    }

    public record Execution
    {
        
    }
}