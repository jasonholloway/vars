using System.Collections.Immutable;
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
                plan.Roots.Select(u => ((PlanNode.BlockNode)(u.Node)).Outline).First().ToString(),
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
                .RoundUpInputs()
                .ToExecution();
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

    public static class PlanExtensions
    {
        public static Lattice<(ImmutableHashSet<Var> AllInputs, PlanNode Inner)> RoundUpInputs(this Lattice<PlanNode> from)
            => from.MapBottomUp<PlanNode, (ImmutableHashSet<Var> AllInputs, PlanNode Inner)>(
                (node, below) =>
                {
                    var allInps = below.Aggregate(
                        ImmutableHashSet<Var>.Empty,
                        (ac, l) => ac.Union(l.Node.AllInputs)
                        );

                    if (node is PlanNode.BlockNode b)
                    {
                        allInps = allInps.Union(b.Outline.Inputs.Select(v => v.AsSimple()));
                    }

                    //also, need to handle wildcard case
                    
                    return (allInps, node);
                });

        public static Execution ToExecution(this Lattice<(ImmutableHashSet<Var> AllInputs, PlanNode Inner)> plan)
        {
            
            // pins could be propagated up front
            // otherwise we'll come up against a nested dog{dogName=Barbara}
            // and we've got a dog, but is it the right kind to satisfy the above?
            //
            // caching would only work if we store dogName as an input to the dog
            // we come to running it, to providing the vars
            // unless we have a full cached value satisfying the above exactly (as we want the upstream to be consistent with us - transitive dependencies are a thing)
            // we will try resolving it afresh
            // and through the fresh looking at the supplying block, we should hopefully find pre-cached satisfactors of that block
            //
            // a pinning like dog{dogName=Barbara} doesn't tell the whole story of its resolution:
            // really it will be pulling in more inputs than that, each one determinant
            // we need to suss more out about it before going to the cache
            // 
            // but! isn't this the case for minimally-pinned inputs too?
            // yes - all inputs need to be followed to their supplying blocks
            // but the execution of a block can certainly be cached
            // as we know all of its inputs definitively
            //
            // the bubbled inputs are therefore nothing to do with pinnings, which are a layer on top of the bare vars
            // we need to be basifying them then
            
            
            
            return new Execution();
        }
    }
}