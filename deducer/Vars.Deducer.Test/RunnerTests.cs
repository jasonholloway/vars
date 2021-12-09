using System;
using System.Collections.Generic;
using System.Collections.Immutable;
using NUnit.Framework;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
    using static TestHelpers;
    
    public class RunnerTests
    {
        [Test]
        public void Runs()
        {
            var index = Outlines(
                "file4;C;field,farm;flour;",
                "file1;A;eggs,flour;cake;",
                "file2;D;farm;chicken;",
                "file3;B;chicken,flour;eggs;"
            );

            var runner = new TestRunner();

            var env = Planner
                .Plan(index, new VarTarget(new Var("cake")))
                .RoundUpInputs()
                .Perform(runner);

            
        }
    }

    public class TestRunner : IRunner
    {
        readonly List<(Outline, IDictionary<string, Bind>, string[])> _calls = new();

        public Bind[] Invoke(Outline outline, IDictionary<string, Bind> binds, string[] flags)
        {
            _calls.Add((outline, binds, flags));
            return Array.Empty<Bind>();
        }

        public IEnumerable<(Outline Outline, IDictionary<string, Bind> Binds, string[] Flags)> Calls => _calls;
    }

    public interface IRunner
    {
        Bind[] Invoke(Outline outline, IDictionary<string, Bind> binds, string[] flags);
    }

    public static class PlanExtensions2
    {
        public static Env Perform(this Lattice<(ImmutableHashSet<Var>, PlanNode)> plan, IRunner runEnv, Env? env = null)
        {
            env ??= new Env();
            
            env.Bind(("", ""));

            return env;
        }
        
    }

    public class SimpleRunner
    {
        
    }
    
    // running is cooperative with actual executing blocks
    // so can't just test simple output
    // full testing of all branches would involve a branching tree of clauses
    // or mocks
    // or end results
    //
}