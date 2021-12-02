namespace Vars.Deducer.Model
{
    public record Planned(Outline Outline, bool IsTarget)
    {
        public override string ToString()
            => IsTarget
                ? $"*{Outline}"
                : Outline.ToString();
    }
}