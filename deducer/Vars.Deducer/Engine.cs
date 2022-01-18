using Vars.Deducer.Evaluators;
using Vars.Deducer.Tags;

namespace Vars.Deducer;

public static class Engine<X>
{
    public static (X, V) Run<V>(IEvaluator<X> eval, X x, F<V> prog)
    {
        var curr = new Curr { State = x, Value = null };
        curr.Stack.Push(() => prog);
        
        while (curr.Stack.TryPop(out var popped))
        {
            var next = popped();
            var cont = Eval(curr, eval, (dynamic)next);
            Read(curr, cont);
        }

        return (curr.State, (V)curr.Value!);
    }

    static F<V> Eval<V>(Curr curr, object eval, F<V> next) //do we still need to do this???
        => ((IEvaluator<X>)eval).Eval(curr.State!, next);
    
    static void Read(Curr _, Tags.Tags.Id tag)
    {
    }
    
    static void Read<V>(Curr curr, Tags.Tags.Pure<V> tag)
    {
        curr.Value = tag.val;
    }
    
    static void Read<AV, BV>(Curr curr, Tags.Tags.Bind<AV, BV> tag)
    {
        curr.Stack.Push(() => tag.fn((AV)curr.Value!)); //needs to take state as well!!!
        curr.Stack.Push(() => tag.io);
    }

    static void Read<R>(Curr curr, Tags.Tags.Read<R> tag)
    {
        if (curr.State is IState<X, R> state)
        {
            curr.Value = state.Get();
        }
        else
        {
            throw new NotImplementedException($"Context doesn't implement {typeof(IState<X, R>)}");
        }
    }

    static void Read<W>(Curr curr, Tags.Tags.Write<W> tag)
    {
        if (curr.State is IState<X, W> state)
        {
            curr.State = state.Put(tag.val);
            curr.Value = null;
        }
        else
        {
            throw new NotImplementedException($"Context doesn't implement {typeof(IState<X, W>)}");
        }
    }
    
    class Curr
    {
        public X? State { get; set; }
        public object? Value { get; set; }
        public Stack<Func<object>> Stack { get; } = new();
    }
}