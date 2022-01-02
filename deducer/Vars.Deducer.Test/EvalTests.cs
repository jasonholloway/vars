using System;
using System.Threading.Tasks;
using NUnit.Framework;

namespace Vars.Deducer.Test;
using static Ops;

public class EvalTests
{
    IEvaluator _core = new RootEvaluator(
        r => new CoreEvaluator(r)
        );
    
    
    [Test]
    public void Reads()
    {
        var prog = Id().Then(Read<int>);

        var result = _core.Eval(13, prog).Run(_core);
        Assert.That(result, Is.EqualTo((13, 13)));
    }
    
    [Test]
    public void ReadThens()
    {
        var prog = Id().Then(
            ReadThen((int s) =>
            {
                return Pure(s + 1);
            }));

        var result = _core.Eval(13, prog).Run(_core);
        Assert.That(result, Is.EqualTo((13, 14)));
    }
    
    [Test]
    public void ThenThens()
    {
        var prog = Pure(1)
            .Then(i => Pure(i + 1))
            .Then(i => Pure(i + 1));

        var result = _core.Eval(13, prog).Run(_core);
        Assert.That(result, Is.EqualTo((13, 3)));
    }
    
    [Test]
    public void ReadThenThens()
    {
        var prog = ReadThen((int s) => Pure(s + 1))
            .Then(i => Pure(i + 1));

        var result = _core.Eval(13, prog).Run(_core);
        Assert.That(result, Is.EqualTo((13, 15)));
    }
    
    [Test]
    public void Evals()
    {
        var prog = ReadThen((int i) =>
        {
            Console.WriteLine(i.ToString());
            return Pure(3);
        }).Then(i =>
        {
            return Write(i).Then(Pure(20));
        });

        var result = _core.Eval(7, prog).Run(_core);
        Assert.That(result, Is.EqualTo((3, 20)));
    }
}