using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Vars.Deducer.Bash;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    public class BusRunner : IRunner
    {
        readonly TextReader _reader;
        readonly TextWriter _writer;

        public BusRunner(TextReader reader, TextWriter writer)
        {
            _reader = reader;
            _writer = writer;
        }

        public Bind[] Invoke(Outline outline, IDictionary<string, Bind> binds, string[] flags)
        {
            const char RS = (char)30;
            const char EOM = (char)25;
            
            var flagsPart = string.Join(' ', flags);
            var bindsPart = BashSerializer.WriteAssocArray("boundIns", binds.Select(b => (b.Key, b.Value.Value!)).ToArray());
            var bound = new List<Bind>();
            
            Say("@ASK runner");
            Say($"run {flagsPart}{EOM}{bindsPart}{EOM}{outline}");
            Say("@YIELD");
            Say("@END");

            while (Hear2() is var (type, line))
            {
                switch (type)
                {
                    case "bind":
                        var (vn, v) = Split2(line);

                        if (vn is string n)
                        {
                            bound.Add(new Bind(n, v?.Replace(RS.ToString(), "\n"), outline.Bid));
                        }
                        break;
                    
                    case "set": 
                        //TODO!!!
                        break;
                    
                    case "fin":
                        foreach (var b in bound)
                        {
                            if (b.Value is string val)
                            {
                                Say($"bound {outline.Bid} {b.Key} {val.ReplaceLineEndings(EOM.ToString())}");
                            }
                        }
                        
                        return bound.ToArray();
                    
                    default:
                        Say($"{type} {line}");
                        break;
                }
            }

            throw new InvalidOperationException("no 'fin' received from bus!");

            void Say(string s) 
                => _writer.WriteLine(s);

            string? Hear()
                => _reader.ReadLine();
            
            (string?, string?)? Hear2()
                => Hear() is string line
                    ? Split2(line)
                    : null;
                    }
        
            (string?, string?) Split2(string? str)
            {
                var parts = str?.Split(" ", 2, StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries) ?? Array.Empty<string>();
                return (parts.ElementAtOrDefault(0), parts.ElementAtOrDefault(1));
            }
    }
}