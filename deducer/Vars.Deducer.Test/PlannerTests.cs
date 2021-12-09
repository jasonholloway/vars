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
            
            // a VarExp doesn't require an input if it is self-sufficient, ie an identity
            // dogName{dogName=Bert}
            // shouldn't add to AllInputs
            // as it won't bind to anything, won't be affecting anything above
            // or if it is going to be bubbled, then its explicit pinning needs to be included as the full expression retains its meaning, though displaced
            
            // we still have bound vars in the context
            // when we come across a simple block with a simple input, without any upstreams
            // then if the var is in the scope, then we use it simply
            // we've got a dog, don't need no other complication
            
            // but if it's a var with upstreams,
            // (eg we need a kennel to get a dog)
            // then can we just use the dog we have? depends if the kennel factory is happy with our scope
            // if its been run with all the same inputs as curently available
            // then we can just use its previous output
            //
            // but then in this case, we're not using bindings of vars, but a block cache
            // except the block cache itself requires the vars scope
            // so we have to have a vars scope, and we have to have an execution cache
            // an execution unloads its outputs into the scope
            //
            // a var pinned from above alters the scope however
            // so each nested execution is its own world
            // and its outputs are only merged right at the top, which seems severe
            //
            // execution works from the bottom up
            // 
            // petShop
            //  |     \
            // dog    cat
            //  |       \
            // food     food
            //
            // so, above, food would be set as soon as the first is chosen
            // we expect scope to be global
            // unless we have explicit pinnings
            // 
            // petShop
            //  |      \
            // dog       cat
            //  |          \
            // food{t=chum}  food{t=sheeba}
            //
            // explicitly-pinned vars as above are clearly, lexically not the same var
            // the resolution of such a var will therefore miss the var scope cache
            // and send us on our way to find a supplying block
            // albeit with a new var in the scope
            // and this var will not be global
            // rewriting supplying blocks to make this pinned var exist outside of the normal global scope was the intended mechanism before
            // scopes via rewrites
            // global scope unless opted into
            // if we don't have global scope then we'l end up being prompted repeatedly for the same
            // so opting into scoping is reasonable, necessary even
            // there needs to be some way of pooling context
            // 
            // when we enter a sub-scope, most vars will still be supplied by the superior layer
            // any vars derived within the scope will however be different and unusable outside of the scope
            // unless they happen to not use any vars specific to the scope
            //
            // ------------------------------------------
            //
            // so, when walking through and executing, we assign to the current scope (usually global)
            // though not always... when resolving a var with an explicit pin, then a new scope is created 
            // and popped off on the finish of the resolution
            // 
            // so we need a scoping mechanism if we're doing away with rewriting 
            // scoping is much better than rewriting
            // the executioncache will allow scopes to meet
            // though also the var cache will do the same
            //
            // will dog{name=Bert} then be put in the superion var scope?
            // I'd say yes, but it might then become available in inferior scopes
            // but with other surroundings. the resolution of dog{name=Bert} won't just depend
            // on name=Bert, but on other inputs that might now be shadowed
            //
            // this goes for all other vars: going into a subscope with some shadowings can render percolations from above inconsistent
            // they really should be rederived in the new circumstances
            // but then this leads to repeated prompting
            // we should know if a var from above needs to be rederived
            // by its inputs, the story of its derivation which we shouldn't throw away
            //
            // when entering a scope, we should remove all vars that are unsettled by the new pinning - just do it once, in one place
            // all the binds that lead up to a var are to be tracked
            //
            // dog{name=Bert} depends then on name=Bert, quite clearly
            // but all vars depends on a graph of binds that led up to their possibility
            //
            // the possibility of inconsistency is lame, but perhaps it can be tolerated
            // if we are to tolerate it, then superior scopes will leak through into child scopes completely
            // --------------
            //
            // blockScopes - say if there are two blocks with pin:target=Shipments or whatever...
            // then do we really create two completely separate and coexistent worlds for these two?
            // surely we're expecting as much as possible to be bound globally
            // chucking everything in a subscope away is lame
            //
            // but things dependent on the principle binding of the scope do need to fall away, while also being sharable with sibling scopes
            // it's almost as if each binding should be tracked as depending on other bindings
            // when we enter a scope, then we block bindings that are incompatible with our pins
            // and when we bind within any scope, then we bind not just into a tiered collection of flat sets, but into a tree of dependencies
            //
            
            //
            //  we need a dog, given our current collection of binds in our projected flat set of such
            // we can then look up some dogs, either top down, whittling down from whatever dog binds we have available
            // or searching from below
            // what would be nicest of all would be whittling down on every bind, so that what we see is what is available to us
            // want a dog? simply lookup a dog - this is the interface we want at least
            //
            // going into a scope binds, and by doing so our available vars change
            // such a mechanism would let us wander around without up-front scope management
            // WANTED: AN IMMUTABLE SET OF BINDS, EACH OF WHICH RELATING TO OTHER UPSTREAM BINDS
            // 
            // --------------------------------------------
            // how to get this in piecemeal?
            // we need to be able to run from C# - this is a first step
            // and the simplest runner would just not do scopes
            // it would have to do pins, but these could just be global
            // everything proceeds in a line - mostly like now
            
            
            return new Execution();
        }
    }
}