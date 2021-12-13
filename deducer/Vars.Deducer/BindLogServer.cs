using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using Argus.IO;

namespace Vars.Deducer
{
    public static class BindLogServer
    {
        const string LogFilePath = "/home/jason/.vars/context";
        
        public static IEnumerable<string> DredgeFor(string name)
        {
            using var reader = new ReverseFileReader(LogFilePath);
            
            var found = new List<string>();
            if(reader.ReadLine() is string line && line.StartsWith($"{name}="))
            {
                found.Add(line[(name.Length + 1)..]);
            }

            return found.Distinct();
        }

        public static void Log(IEnumerable<Bind> binds)
        {
            using var writer = new StreamWriter(LogFilePath, true, Encoding.UTF8);

            foreach (var bind in binds)
            {
                // Console.Error.WriteLine($"LOGGIN {bind}");
                writer.WriteLine($"{bind.Key}={bind.Value}");
            }
            
            writer.Flush();
        }

        public static void Log(params Bind[] binds)
            => Log(binds.AsEnumerable());
    }
}