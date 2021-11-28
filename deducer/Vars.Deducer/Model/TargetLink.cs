namespace Vars.Deducer.Model
{
    public record TargetLink(Target Target, BlockLink[] Suppliers);

    public record BlockLink(Outline? Block, TargetLink[] Requirements);
}