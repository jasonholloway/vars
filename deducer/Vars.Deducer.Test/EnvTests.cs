using System;
using System.Collections.Immutable;
using NUnit.Framework;

namespace Vars.Deducer.Test
{
    public record Bind(string Key, string? Value, params Bind[] Upstreams);

    public class Env
    {
        ImmutableDictionary<string, string> _current = ImmutableDictionary<string, string>.Empty;
        ImmutableDictionary<string, string[]> _links = ImmutableDictionary<string, string[]>.Empty;

        public void Bind((string Name, string Value) bind, params Bind[] upstreams)
        {
            _current = _current.SetItem(bind.Name, bind.Value);
            
            //how is the graph going to be shaped?
            //we want to check consistency, mostly
            //when forking, a new graph is created with incompatibles removed
            
            //the roots of the graph are in the current context
            //
            //
        }
        
        public void Fork((string Name, string Value) bind, params Bind[] upstreams)
        {
            throw new NotImplementedException();
        }

        public void Pop()
        {
            throw new NotImplementedException();
        }
        
        public Bind this[string name] => new(name, null);
    };
    
    public class EnvTests
    {
        public void Binds()
        {
            // prizeDog
            //   <- prize <- competition
            //   <- dogSize{dogName=Bruce},dogSize{dogName=Bob} <- dogName

            var env = new Env();
            
            env.Bind(("competition", "Crufts"));
            env.Bind(("prize", "Biggest Dog in Contest"), env["competition"]);
                
            Assert.That(env["prize"].Value, Is.EqualTo("Biggest Dog in Contest"), 
                "should be immediately available in scope after bind");

            env.Fork(("dogName", "Bruce"));
            env.Bind(("dogSize", "diminutive"), env["dogName"]);

            Assert.That(env["dogSize"].Value, Is.EqualTo("diminutive"), 
                "should be immediately available in scope after bind");

            env.Pop();
            
            Assert.That(env["dogName"].Value, Is.Null,
                "popping should return to previous frame");
            
            //though also bind tree accumulates throughout...
            //if we do the popping then there's no point in it being immutable
            //all progress is progress

            env.Fork(("dogName", "Bob"));
            env.Bind(("dogSize", "as big as a horse"), env["dogName"]);
            
            Assert.That(env["dogName"].Value, Is.EqualTo("Bob"), 
                "should be immediately available in scope after fork");
            
            Assert.That(env["competition"].Value, Is.EqualTo("Crufts"), 
                "parent scope's binds should be available");

            var dogName = env["dogName"];
            var dogSize = env["dogSize"];

            env.Pop();
            env.Bind(("prizeDog", "Bob"), dogName, dogSize);

            //but wot bout incompatible ones?
        }
    }
}