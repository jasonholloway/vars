using NUnit.Framework;

namespace Vars.Deducer.Test
{
    public class Tests
    {
        [SetUp]
        public void Setup()
        { }

        [Test]
        public void ParsesOutlines()
        {
            var raw = @"/some/file,1635886830|0;;;firstName,age; /some/other/file,1635886830|1;;;dog; rootFile,1635886830|2;;dog;food;";
            var parsed = Outlines.Parse(raw);
            
            Assert.That(parsed.Items, Has.Length.EqualTo(3));
        }

    }
}