namespace Vars.Deducer
{
    public record Bind(string Key, string? Value, params Bind[] Upstreams);
}