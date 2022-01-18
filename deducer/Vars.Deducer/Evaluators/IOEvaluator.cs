using System.Collections.Immutable;
using Vars.Deducer.Bash;
using Vars.Deducer.Tags;

namespace Vars.Deducer.Evaluators
{
    using static Ops;

    public static class IOEvaluatorExtensions
    {
        public static EvaluatorBuilder<X> AddIOEvaluator<X>(this EvaluatorBuilder<X> builder, TextReader input, TextWriter output)
            => builder with { EvalFacs = builder.EvalFacs.Add(root => new IOEvaluator<X>(root, input, output)) };
    }

    public class IOEvaluator<X> : EvaluatorBase<X>
    {
        readonly TextReader _input;
        readonly TextWriter _output;

        public IOEvaluator(IEvaluator<X> root, TextReader input, TextWriter output) : base(root)
        {
            _input = input;
            _output = output;
        }

        public F<Nil> Match(X x, CoreTags.Say tag)
        {
            _output.WriteLine(tag.Line);
            return Id();
        }
        
        public F<string?> Match(X x, CoreTags.Hear tag)
        {
            var line = _input.ReadLine();
            return Pure(line);
        }
        
        
        public F<string[]> Match(X x, DeducerTags.DredgeBindLog tag)
            => Pure(new[] { "blah", "blah", "blah" });

        public F<Nil> Match(X x, DeducerTags.AppendToBindLog tag)
            => Id();

        public F<string?> Match(X x, DeducerTags.PickValue tag)
            => Say(
                    $"pick {tag.Name} {BashSerializer.WriteAssocArray("options", tag.Values.Select(v => (v, "1")).ToArray())}",
                    "@YIELD"
                )
                .Then(Hear())
                .Then(line =>
                {
                    return Pure(line);
                });
        
        
        const char RS = (char)30;
        const char EOM = (char)25;

        public F<Bind[]> Match(X x, DeducerTags.InvokeRunner tag) 
        {
            var flagsPart = string.Join(' ', tag.RunFlags);
            var bindsPart = BashSerializer.WriteAssocArray("boundIns",
                tag.Binds.Select(b => (b.Key, b.Value!)).ToArray());

            return Say(
                    "@ASK runner",
                    $"run {flagsPart}{EOM}{bindsPart}{EOM}{tag.Outline}",
                    "@YIELD",
                    "@END"
                )
                .Then(
                    Gather(
                        ImmutableArray<Bind>.Empty,
                        (loop, ac) => Hear2().Then(heard =>
                        {
                            if (heard is (string type, var args))
                            {
                                switch (type)
                                {
                                    case "bind" when Split2(args) is (string vn, string v):
                                        var newBind = new Bind(vn, v.Replace(RS.ToString(), "\n"), tag.Outline.Bid);
                                        return loop.Continue(ac.Add(newBind));

                                    case "set":
                                        //TODO!!!
                                        break;

                                    case "fin":
                                        return Pure(ac.AsEnumerable())
                                            .LoopThru(b => 
                                                b.Value is string val
                                                    ? Say($"bound {tag.Outline.Bid} {b.Key} {val.ReplaceLineEndings(EOM.ToString())}")
                                                    : Pure(default(Nil)))
                                            .Then(loop.End(ac));

                                    default:
                                        return Say($"{type} {args}")
                                            .Then(loop.Continue(ac));
                                }
                            }
                            
                            return loop.Continue(ac);
                        })
                    ))
                .Map(bs => bs.ToArray());
        }
        
        public F<Bind[]> Match(X x, DeducerTags.GetUserPins tag)
            => Say(
                    $"getPins {string.Join(" ", tag.Names)}",
                    "@YIELD"
                )
                .Then(
                    Gather(
                        ImmutableArray<Bind>.Empty,
                        (loop, ac) => Hear2().Then(heard =>
                        {
                            if (heard is (string type, var args))
                            {
                                switch (type)
                                {
                                    case "bind" when Split2(args) is (string vn, string v):
                                        var newBind = new Bind(vn, v.Replace(RS.ToString(), "\n"), "pinned");
                                        return loop.Continue(ac.Add(newBind));

                                    case "fin":
                                        return Pure(ac.AsEnumerable())
                                            .LoopThru(b => 
                                                b.Value is string val
                                                    ? Say($"bound pinned {b.Key} {val.ReplaceLineEndings(EOM.ToString())}")
                                                    : Pure(default(Nil)))
                                            .Then(loop.End(ac));

                                    default:
                                        return Say($"{type} {args}")
                                            .Then(loop.Continue(ac));
                                }
                            }
                            
                            return loop.Continue(ac);
                        })
                    ))
                .Map(bs => bs.ToArray());
        
        static (string?, string?) Split2(string str)
        {
            var parts = str.Split(" ", 2, StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
            return (parts.ElementAtOrDefault(0), parts.ElementAtOrDefault(1));
        }
    }
}