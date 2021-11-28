using System.Linq;
using NUnit.Framework;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
    public class DeducerTests
    {
        [Test]
        public void PutsInOrder()
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
            Assert.That(ordered.SelectMany(o => o.Names), Is.EqualTo(new[] { "D", "C", "B", "A" }));
        }

        [Test]
        public void PutsInOrder2()
        {
            var index = Outlines(
                "file,1635886830|0;;;firstName,age;",
                "file,1635886830|1;;;dog;",
                "file,1635886830|2;;dog;food;",
                "file,1635886830|3;sayHello;dog;;",
                "file,1635886830|4;greet;firstName;;",
                "file,1635886830|5;sayMoo;cowName,breed;;P",
                "file,1635886830|6;;;cowName;",
                "file,1635886830|7;less;;blah;",
                "file,1635886830|8;vim;;blah;",
                "file,1635886830|9;curl;cowName;;",
                "file,1635886830|10;;;prefix;",
                "file,1635886830|11;;;site;",
                "file,1635886830|12;;prefix,site{via=uk};url;",
                "file,1635886830|13;;url;ip;C",
                "file,1635886830|14;;ip{site=sorted+url=blah.com};sortedIp;",
                "file,1635886830|15;;ip;googleIp;P",
                "file,1635886830|16;;sortedIp,googleIp;bothIps;",
                "file,1635886830|17;;ip{site=sorted},ip{site=google};bothIpsIdeal;",
                "file,1633205052|0;;;;",
                "file,1633205052|1;;age;hat,cat;",
                "file,1633205052|2;getSurname;;surname;",
                "file,1633205052|3;curl;age;;",
                "file,1634681688|0;;;;",
                "file,1634681688|1;;dog;food;",
                "file,1634681688|2;;env;k8s;",
                "file,1634421696|0;;;;",
                "file,1634421696|1;;prefix,site;url2;"
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