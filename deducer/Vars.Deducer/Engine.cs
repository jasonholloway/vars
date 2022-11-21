using Vars.Deducer.Evaluators;
using Vars.Deducer.Tags;

namespace Vars.Deducer;

public class Engine<X> : TagVisitor
{
    private Engine() {}
    
    X? _state { get; set; }
    object? _val { get; set; }
    Stack<Func<Tag>> _stack { get; } = new();
    
    public static (X, V) Run<V>(IEvaluator<X> eval, X x, Tag<V> prog)
    {
        var curr = new Engine<X> { _state = x, _val = null };
        curr._stack.Push(() => prog);
        
        while (curr._stack.TryPop(out var popped))
        {
            switch(eval.Eval(curr._state, popped()))
            {
                case VisitableTag t:
                    t.Receive(curr);
                    break;
                    
                default:
                    throw new NotImplementedException("bah!");
            };
        }

        return (curr._state, curr._val is V val ? val : default);
    }

    public void Visit(Tags.Tags.Id tag)
    { }

    public void Visit<V>(Tags.Tags.Pure<V> tag)
    {
        _val = tag.val;
    }

    public void Visit<AV, BV>(Tags.Tags.Bind<AV, BV> tag)
    {
        _stack.Push(() => tag.fn(_val is AV val ? val : default)); //needs to take state as well!!! - or not if state always accessed via Read/Write
        _stack.Push(() => tag.io);
    }

    public void Visit<R>(Tags.Tags.Read<R> tag)
    {
        if (_state is IState<X, R> state)
        {
            _val = state.Get();
        }
        else
        {
            throw new NotImplementedException($"Context doesn't implement {typeof(IState<X, R>)}");
        }
    }

    public void Visit<W>(Tags.Tags.Write<W> tag)
    {
        if (_state is IState<X, W> state)
        {
            _state = state.Put(tag.val);
            _val = null;
        }
        else
        {
            throw new NotImplementedException($"Context doesn't implement {typeof(IState<X, W>)}");
        }
    }
}