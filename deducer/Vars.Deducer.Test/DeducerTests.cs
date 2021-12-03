using System.Linq;
using NUnit.Framework;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
    using static StringHelpers;
    
    public class DeducerTests
    {
        // 
        //
        //
        //
        //
    
    
        
        [Test]
        public void TargetsVar()
        {
            var index = Outlines(
                "file4;C;field{crop=wheat},farm;flour;",
                "file1;A;eggs,flour;cake;",
                "file2;D;farm;chicken;",
                "file3;B;chicken,flour;eggs;"
                );

            var plan = Deducer.Deduce(index, new VarTarget(new Var("cake")));
            TestContext.WriteLine(plan.ToString());
            
            Assert.That(plan.ToString(), 
                Is.EqualTo(Lines(@"
                    file2;D;farm;chicken;
                    file4;C;field,farm;flour;
                    file3;B;chicken,flour;eggs;
                    *file1;A;eggs,flour;cake;
                ")));
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
                "file,123|6;;;cowName;"
                );

            var plan = Deducer.Deduce(index, new BlockTarget("sayMoo"));
            TestContext.WriteLine(plan);
            
            Assert.That(plan.ToString(),
                Is.EqualTo(Lines(@"
                    file,123|6;;;cowName;
                    *file,123|5;sayMoo;cowName,breed;;P
                ")));
        }

        static OutlineIndex Outlines(params string[] rawOutlines)
            => new(rawOutlines.Select(Outline.Parse));
    }
}