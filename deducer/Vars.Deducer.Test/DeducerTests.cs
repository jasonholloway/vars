using System.Linq;
using NUnit.Framework;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
    public class DeducerTests
    {
        [Test]
        public void TargetsVar()
        {
            var index = Outlines(
                "file4;C;field,farm;flour;",
                "file1;A;eggs,flour;cake;",
                "file2;D;farm;chicken;",
                "file3;B;chicken,flour;eggs;"
                );

            var ordered = Deducer.Deduce(index, new VarTarget(new Var("cake")));

            foreach (var ol in ordered)
            {
                TestContext.WriteLine(ol.ToString());
            }

            Assert.That(ordered, Has.Length.EqualTo(4));
            Assert.That(ordered.SelectMany(o => o.Outline.Names), Is.EqualTo(new[] { "D", "C", "B", "A" }));
        }

        [Test]
        public void TargetsBlock()
        {
            var index = Outlines(
                "file,123|0;;;firstName,age;",
                "file,123|1;;;dog;",
                "file,123|2;;dog;food;",
                "file,123|3;sayHello;dog;;",
                "file,123|4;greet;firstName;;",
                "file,123|5;sayMoo;cowName,breed;;P",
                "file,123|6;;;cowName;",
                "file,123|7;less;;blah;",
                "file,123|8;vim;;blah;",
                "file,123|9;curl;cowName;;",
                "file,123|10;;;prefix;",
                "file,123|11;;;site;",
                "file,123|12;;prefix,site{via=uk};url;",
                "file,123|13;;url;ip;C",
                "file,123|14;;ip{site=sorted+url=blah.com};sortedIp;",
                "file,123|15;;ip;googleIp;P",
                "file,123|16;;sortedIp,googleIp;bothIps;",
                "file,123|17;;ip{site=sorted},ip{site=google};bothIpsIdeal;",
                "file,123|0;;;;",
                "file,123|1;;age;hat,cat;",
                "file,123|2;getSurname;;surname;",
                "file,123|3;curl;age;;",
                "file,123|0;;;;",
                "file,123|1;;dog;food;",
                "file,123|2;;env;k8s;",
                "file,123|0;;;;",
                "file,123|1;;prefix,site;url2;"
                );

            var ordered = Deducer.Deduce(index, new BlockTarget("sayMoo"));

            foreach (var ol in ordered)
            {
                TestContext.WriteLine(ol.ToString());
            }
        }

        static OutlineIndex Outlines(params string[] rawOutlines)
            => new(rawOutlines.Select(Outline.Parse));
    }
}