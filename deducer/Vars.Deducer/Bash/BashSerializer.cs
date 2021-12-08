using System.Linq;
using System.Text;

namespace Vars.Deducer.Bash
{
    public class BashSerializer
    {
        public static string WriteAssocArray(string name, params (string Name, string Val)[] kvs)
        {
            var sb = kvs.Aggregate(
                new StringBuilder($"declare -A {name}=("),
                (ac, kv) => ac.Append($@"[{kv.Name}]=$'{kv.Val}' ")
            );
            
            sb.Append(')');
            return sb.ToString();
        }
    }
}