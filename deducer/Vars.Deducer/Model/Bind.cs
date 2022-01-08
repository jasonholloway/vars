namespace Vars.Deducer
{
    public record Bind(string Key, string? Value, string? Source = null, params Bind[] Upstreams);
}