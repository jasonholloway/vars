using System;
using System.Collections.Generic;
using System.Linq;
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
                .RoundUpInputs()
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

    public class TestRunner : IRunner
    {
        readonly ILookup<string, Func<Bind[]?>> _responses;
        readonly List<(string Bid, IDictionary<string, Bind> Binds, string[] Flags)> _calls = new();

        public TestRunner(params (string Bid, Func<Bind[]?> GetBinds)[] responses)
        {
            _responses = responses.ToLookup(t => t.Bid, t => t.GetBinds);
        }

        public Bind[] Invoke(string bid, IDictionary<string, Bind> binds, string[] flags)
        {
            _calls.Add((bid, binds, flags));
            
            return _responses[bid]
                .Aggregate(
                    new Func<Bind[]>(() => Array.Empty<Bind>()), 
                    (ac, el) => () => ac().Concat(el() ?? Array.Empty<Bind>()).ToArray())
                .Invoke();
        }

        public IEnumerable<(string Bid, IDictionary<string, Bind> Binds, string[] Flags)> Calls => _calls;

        public IEnumerable<string> CalledBids => _calls.Select(c => c.Item1);
    }

    // running is cooperative with actual executing blocks
    // so can't just test simple output
    // full testing of all branches would involve a branching tree of clauses
    // or mocks
    // or end results
    //
}