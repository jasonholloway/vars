using System;
using System.Collections.Generic;
using NUnit.Framework;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
    using static TestHelpers;
    
    public class TestRunnerTests
    {
        [Test]
        public void RunsPseudoBlocks()
        {
            var runner = Blocks(
                ("block1", () => new[] { new Bind("kitten", "Charles") }),
                ("block2", () => null),
                ("block3", () => null)
            );

            var binds = runner.Invoke(Outline.Parse("block1"), new Dictionary<string, Bind>(), Array.Empty<string>());
            
            Assert.That(binds, Is.EqualTo(new[] { new Bind("kitten", "Charles") }));
        }
        
    }
}