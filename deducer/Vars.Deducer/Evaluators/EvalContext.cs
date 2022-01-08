namespace Vars.Deducer;

public interface IState<out TSelf, TState> 
{
    TState Get();
    TSelf Put(TState state);

    TState Zero { get; }
    TState Combine(TState left, TState right);
}