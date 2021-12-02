using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace Vars.Deducer.Model
{
    public class OutlineSynthesizer
    {
        public IEnumerable<Outline> Synthesize(Target target)
        {
            switch (target)
            {
                case BlockTarget(var name):
                    var matched = Regex.Match(name, @"^get:([^:]+)$");
                    if (matched.Success)
                    {
                        return EnumerableEx.Return(new Outline(
                            name, 
                            new[] { name }, 
                            new[] { new Var(matched.Groups[1].Value) }, 
                            Array.Empty<Var>(), 
                            new[] { "T" }
                        ));
                    }
                    break;
            }
            
            return Enumerable.Empty<Outline>();
        }
    }
}