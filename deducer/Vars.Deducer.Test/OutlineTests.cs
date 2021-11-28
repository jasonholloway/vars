using System;
using System.Linq;
using NUnit.Framework;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
    public class OutlineTests
    {
        [Test]
        public void Parses1()
        {
            var parsed = Outline.Parse(@"/some/file,123|1;;breed{hair=long},pedigree;dog;P");
            
            Assert.Multiple(() =>
            {
                Assert.That(parsed.Bid, Is.EqualTo("/some/file,123|1"));
                
                Assert.That(parsed.Inputs, 
                    Is.EqualTo(new[]
                    {
                        Var("breed", Pin("hair", "long")),
                        Var("pedigree") 
                    }));
                
                Assert.That(parsed.Outputs, 
                    Is.EqualTo(new[]
                    {
                        Var("dog")
                    }));
                
                Assert.That(parsed.Flags, Is.EqualTo(new[] { "P" }));
            });
        }
        
        [Test]
        public void ParsesEmpty()
        {
            var parsed = Outline.Parse(@"bid;;;;");
            
            Assert.Multiple(() =>
            {
                Assert.That(parsed.Bid, Is.EqualTo("bid"));
                Assert.That(parsed.Names, Is.Empty);
                Assert.That(parsed.Inputs, Is.Empty);
                Assert.That(parsed.Outputs, Is.Empty);
                Assert.That(parsed.Flags, Is.Empty);
            });
        }
        
        [Test]
        public void OutlineRoundtrip()
        {
            var raw = @"/some/other/file,123|1;;;dog{breed=Pomeranian};P";
            var parsed = Outline.Parse(raw);

            Assert.That(parsed.ToString(), Is.EqualTo(raw));
        }
        
        public static Var Var(string name, params Pin[] pins)
            => new(name, pins.ToHashSet());

        public static Pin Pin(string varName, string val)
            => new(varName, val);
    }
}