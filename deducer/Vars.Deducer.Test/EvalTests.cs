using System;
using NUnit.Framework;
using Vars.Deducer.Evaluators;
using Vars.Deducer.Tags;

namespace Vars.Deducer.Test;

using static Ops;

public class EvalTests
{
    IEvaluator<Context> _core = EvaluatorBuilder
        .WithContext<Context>()
        .AddCoreEvaluator()
        .AddTestEvaluator()
        .Build();

    (Context State, V Value) Run<V>(Context x, F<V> prog) => Engine<Context>.Run(_core, x, prog);

    [Test]
    public void EvalsId()
    {
        var prog = Id();

        var result = Run(new Context(), prog);
        Assert.That(result, Is.Not.Null);
    }
    
    [Test]
    public void IdThenId()
    {
        var prog = Id().Then(Id());

        var result = Run(new Context(), prog);
        Assert.That(result, Is.Not.Null);
    }

    [Test]
    public void Reads()
    {
        var prog = Id().Then(Read<int>);

        var result = Run(new Context(13), prog);
        Assert.That((result.State, result.Value), 
            Is.EqualTo((new Context(13), 13)));
    }

    [Test]
    public void ReadThens()
    {
        var prog = Id().Then(
            ReadThen((int s) =>
            {
                return Pure(s + 1);
            }));

        var result = Run(new Context(13), prog);
        Assert.That((result.State, result.Value), Is.EqualTo((new Context(13), 14)));
    }
    
    [Test]
    public void ThenThens()
    {
        var prog = Pure(1)
            .Then(i => Pure(i + 1))
            .Then(i => Pure(i + 1));

        var result = Run(new Context(13), prog);
        Assert.That((result.State, result.Value), 
            Is.EqualTo((new Context(13), 3)));
    }
    
    [Test]
    public void ReadThenThens()
    {
        var prog = ReadThen((int s) => Pure(s + 1))
            .Then(i => Pure(i + 1));

        var result = Run(new Context(13), prog);
        Assert.That((result.State, result.Value), 
            Is.EqualTo((new Context(13), 15)));
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

        var result = Run(new Context(7), prog);
        Assert.That((result.State, result.Value), 
            Is.EqualTo((new Context(10), 20)));
    }
    
    [Test]
    public void Loops1()
    {
        var prog = 
            Pure(new[] { 1, 2, 3 })
            .LoopThru(i => Write(i));

        var result = Run(new Context(), prog);
        Assert.That((result.State, result.Value), 
            Is.EqualTo((new Context(6), default(Nil))));
    }
    
    [Test]
    public void Loops2()
    {
        var prog = new[] { Pure(1), Pure(2), Pure(3) }
            .LoopThru(i => Write(i));

        var result = Run(new Context(), prog);
        Assert.That((result.State, result.Value), 
            Is.EqualTo((new Context(6), default(Nil))));
    }
    
    [Test]
    public void Gathers1()
    {
        var prog = Gather(13, 
            (loop, ac) => ac < 30 
                ? loop.Continue(ac * 2) 
                : loop.End(ac)
                );

        var result = Run(new Context(), prog);
        Assert.That((result.State, result.Value), 
            Is.EqualTo((new Context(), 52)));
    }
    
    [Test]
    public void Gathers2()
    {
        var prog = Gather(13, 
            (loop, ac) => ac < 30 
                ? Write(1).Then(loop.Continue(ac * 2)) 
                : Write(7).Then(loop.End(ac))
                );

        var result = Run(new Context(), prog);
        Assert.That((result.State, result.Value), 
            Is.EqualTo((new Context(9), 52)));
    }
    

    public record Context(int State = 0) : IState<Context, int>
    {
        int IState<Context, int>.Get()
            => State;

        Context IState<Context, int>.Put(int state)
            => new(((IState<Context, int>)this).Combine(State, state));

        int IState<Context, int>.Zero => 0;

        int IState<Context, int>.Combine(int left, int right)
            => left + right;
    }
}