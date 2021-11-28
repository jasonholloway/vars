using System.Linq;
using NUnit.Framework;

namespace Vars.Deducer.Test
{
    public class Tests
    {
        public static Var Var(string name, params Pin[] pins)
            => new(name, pins.ToHashSet());

        public static Pin Pin(string varName, string val)
            => new(varName, val);
        
        
        [Test]
        public void ParsesOutlines()
        {
            var raw = @"/some/file,123|1;;breed{hair=long},pedigree;dog; rootFile,1635886830|2;;dog;food;";
            var parsed = Outlines.Parse(raw).Items;
            
            Assert.Multiple(() =>
            {
                Assert.That(parsed, Has.Length.EqualTo(2));
                Assert.That(parsed[0].Bid, Is.EqualTo("/some/file,123|1"));
                
                Assert.That(parsed[0].Inputs, 
                    Is.EqualTo(new[]
                    {
                        Var("breed", Pin("hair", "long")),
                        Var("pedigree") 
                    }));
                
                Assert.That(parsed[0].Outputs, 
                    Is.EqualTo(new[]
                    {
                        Var("dog")
                    }));
            });
        }
        
        [Test]
        public void OutlineRoundtrip()
        {
            var raw = @"/some/file,123|0;;;firstName,age; /some/other/file,123|1;;;dog{breed=Pomeranian}; rootFile,123|2;;dog;food;";
            var parsed = Outlines.Parse(raw);

            var written = string.Join(' ', parsed.Items.Select(o => o.ToString()));
            Assert.That(written, Is.EqualTo(raw));
        }
    }
    
    public class VarTests 
    {
        [Test]
        public void Parses()
        {
            var @var = Var.Parse("dog");
            Assert.That(@var.Name, Is.EqualTo("dog"));
            Assert.That(@var.Pins, Is.Empty);
            
            var @var2 = Var.Parse("pig{breed=Berkshire+age=3}");
            Assert.That(@var2.Name, Is.EqualTo("pig"));
            Assert.That(@var2.Pins, Is.EquivalentTo(new[]
            {
                new Pin("age", "3"),
                new Pin("breed", "Berkshire"), 
            }));
        }
        
        [Test]
        public void Roundtrips()
        {
            var raw = "pig{breed=Berkshire+age=3}";
            var parsed = Var.Parse(raw);
            Assert.That(parsed.ToString(), Is.EqualTo(raw));
        }
        
        [TestCase("pig")]
        [TestCase("pig{breed=Berkshire+age=3}")]
        public void Equates(string raw)
        {
            var parsed1 = Var.Parse(raw);
            var parsed2 = Var.Parse(raw);
            Assert.That(parsed1, Is.EqualTo(parsed2));
        }
        
        [TestCase("pig" , "pog")]
        [TestCase("pig{A=1+B=2}" , "pig{A=1+B=5}")]
        public void Differentiates(string raw1, string raw2) 
        {
            var parsed1 = Var.Parse(raw1);
            var parsed2 = Var.Parse(raw2);
            Assert.That(parsed1, Is.Not.EqualTo(parsed2));
        }
    }
    
    public class PinTests 
    {
        [Test]
        public void Parses()
        {
            var pin = Pin.Parse("fabric=wool");
            Assert.That(pin.VarName, Is.EqualTo("fabric"));
            Assert.That(pin.Value, Is.EqualTo("wool"));
        }
        
        [Test]
        public void Roundtrips()
        {
            var raw = "fabric=wool";
            var parsed = Pin.Parse(raw);
            Assert.That(parsed.ToString(), Is.EqualTo(raw));
        }

        [Test]
        public void Equates()
        {
            var raw = "fabric=wool";
            var parsed1 = Pin.Parse(raw);
            var parsed2 = Pin.Parse(raw);
            Assert.That(parsed1, Is.EqualTo(parsed2));
        }
    }
}