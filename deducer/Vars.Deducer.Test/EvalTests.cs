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
        var prog = Id<int>().Read();

        var result = _core.Eval(13, prog).Run(_core);
        Assert.That(result, Is.EqualTo((13, 13)));
    }
    
    [Test]
    public void ReadThen()
    {
        var prog = Id<int>().ReadThen((x, s) =>
        {
            return x.Pure(s + 1);
        });

        var result = _core.Eval(13, prog).Run(_core);
        Assert.That(result, Is.EqualTo((13, 14)));
    }
    
    [Test]
    public void ThenThen()
    {
        var prog = Id<int>()
            .Pure(1)
            .Then((x, i) =>
            {
                return x.Pure(i + 1);
            })
            .Then((x, i) =>
            {
                return x.Pure(i + 1);
            });

        var result = _core.Eval(13, prog).Run(_core);
        Assert.That(result, Is.EqualTo((13, 3)));
    }
    
    [Test]
    public void ReadThenThen()
    {
        var prog = Id<int>()
            .ReadThen((x, s) =>
            {
                return x.Pure(s + 1);
            })
            .Then((x, i) =>
            {
                return x.Lift(i + 1);
            });

        var result = _core.Eval(13, prog).Run(_core);
        Assert.That(result, Is.EqualTo((13, 15)));
    }
    
    [Test]
    public void Evals()
    {
        var prog = Id<int>().ReadThen((x, i) =>
        {
            Console.WriteLine(i.ToString());
            return x.Pure(3);
        }).Then((x, i) =>
        {
            return x.Write(i).Lift(20);
        });

        var result = _core.Eval(7, prog).Run(_core);
        Assert.That(result, Is.EqualTo((3, 20)));
    }
}