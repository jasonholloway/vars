using NUnit.Framework;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
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