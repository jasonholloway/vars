using NUnit.Framework;

namespace Vars.Deducer.Test
{
    public class EnvTests
    {
        public void Binds()
        {
            // prizeDog
            //   <- prize <- competition
            //   <- dogSize{dogName=Bruce},dogSize{dogName=Bob} <- dogName

            var env = new Env();
            
            env.Add(("competition", "Crufts"));
            env.Add(("prize", "Biggest Dog in Contest"), env["competition"]);
                
            Assert.That(env["prize"].Value, Is.EqualTo("Biggest Dog in Contest"), 
                "should be immediately available in scope after bind");

            env.Fork(("dogName", "Bruce"));
            env.Add(("dogSize", "diminutive"), env["dogName"]);

            Assert.That(env["dogSize"].Value, Is.EqualTo("diminutive"), 
                "should be immediately available in scope after bind");

            env.Pop();
            
            Assert.That(env["dogName"].Value, Is.Null,
                "popping should return to previous frame");
            
            //though also bind tree accumulates throughout...
            //if we do the popping then there's no point in it being immutable
            //all progress is progress

            env.Fork(("dogName", "Bob"));
            env.Add(("dogSize", "as big as a horse"), env["dogName"]);
            
            Assert.That(env["dogName"].Value, Is.EqualTo("Bob"), 
                "should be immediately available in scope after fork");
            
            Assert.That(env["competition"].Value, Is.EqualTo("Crufts"), 
                "parent scope's binds should be available");

            var dogName = env["dogName"];
            var dogSize = env["dogSize"];

            env.Pop();
            env.Add(("prizeDog", "Bob"), dogName, dogSize);

            //but wot bout incompatible ones?
        }
    }
}