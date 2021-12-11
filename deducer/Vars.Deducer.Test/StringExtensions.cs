using System;
using System.IO;
using System.Linq;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
    public static class TestHelpers
    {
        public static string Lines(string str)
        {
            var reader = new StringReader(str);
            var writer = new StringWriter();

            while (reader.ReadLine() is string line)
            {
                if (!string.IsNullOrWhiteSpace(line))
                {
                    writer.WriteLine(line.TrimStart());
                }
            }

            return writer.ToString();
        }

        public static OutlineIndex Outlines(params string[] rawOutlines)
            => new(rawOutlines.Select(Outline.Parse));

        public static TestRunner Blocks(params (string Bid, Func<Bind[]?> fn)[] pseudoBlocks)
        {
            return new TestRunner(
                pseudoBlocks
                );
        }
        
        public static TestRunner Blocks(params (string Bid, (string Name, string Val)[] Binds)[] blockBinds)
        {
            var pseudoBlocks = blockBinds
                .Select(s => (
                    s.Bid, 
                    new Func<Bind[]?>(() => s.Binds.Select(b => new Bind(b.Name, b.Val)).ToArray()))
                )
                .ToArray();
            
            return new TestRunner(pseudoBlocks);
        }
    }
}