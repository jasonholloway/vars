using NUnit.Framework;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
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
}