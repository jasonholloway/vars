using System.IO;

namespace Vars.Deducer.Test
{
    public static class StringHelpers
    {
        public static string Lines(string str)
        {
            var reader = new StringReader(str);
            var writer = new StringWriter();

            while (reader.ReadLine() is string line)
            {
                if (!string.IsNullOrWhiteSpace(line))
                {
                    writer.WriteLine(line.TrimStart());
                }
            }

            return writer.ToString();
        }
    }
}