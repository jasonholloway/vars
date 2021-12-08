using NUnit.Framework;
using Vars.Deducer.Bash;

namespace Vars.Deducer.Test
{
    using static BashSerializer;

    public class BashSerializerTests
    {
        [Test]
        public void WritesAssocArray()
            => Assert.That(
                WriteAssocArray("r", ("cat", "Tiddles"), ("dog", "Bruce")), 
                Is.EqualTo("declare -A r=([cat]=$'Tiddles' [dog]=$'Bruce' )")
                );
        
        [Test]
        public void WritesAssocArray_WithNewLines()
            => Assert.That(
                WriteAssocArray("r", 
                    ("cat", @"
blah
blah
") 
                    ), 
                Is.EqualTo("declare -A r=([cat]=$'\nblah\nblah\n' )")
                );
    }
}