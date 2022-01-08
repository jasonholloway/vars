using System.Linq;
using NUnit.Framework;
using Vars.Deducer.Model;

namespace Vars.Deducer.Test
{
    using static TestHelpers;

    public class FlatPlannerTests
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

            var plan = Planner
                .Plan(index, new VarTarget(new Var("cake")))
                .ToFlatPlan();
            
            NUnit.Framework.TestContext.WriteLine(plan.ToString());
            
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

            var plan = Planner
                .Plan(index, new BlockTarget("sayMoo"))
                .ToFlatPlan();
            
            NUnit.Framework.TestContext.WriteLine(plan);
            
            Assert.That(plan.ToString(),
                Is.EqualTo(Lines(@"
                    file,123|6;;;cowName;
                    *file,123|5;sayMoo;cowName,breed;;P
                ")));
        }
    }
}