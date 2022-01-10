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

        public Cont<X, Nil> Match(X x, CoreTags.Say tag)
        {
            _output.WriteLine(tag.Line);
            return new Return<X, Nil>(x, default);
        }
        
        public Cont<X, string> Match(X x, CoreTags.Hear tag)
        {
            var line = _input.ReadLine();
            return new Return<X, string>(x, line!);
        }
        
        
        public Cont<X, string[]> Match(X x, DeducerTags.DredgeBindLog tag)
            => new Return<X, string[]>(x, new[] { "woof" });

        public Cont<X, Nil> Match(X x, DeducerTags.AppendToBindLog tag)
            => new Return<X, Nil>(x, default);

        public Cont<X, string?> Match(X x, DeducerTags.PickValue tag)
            => Root.Eval(x,
                Say(
                    $"pick {tag.Name} {tag.Values}",
                    "@YIELD"
                )
                .Then(Hear())
                .Then(line =>
                {
                    return Pure(line);
                })
            );

        public Cont<X, Bind[]> Match(X x, DeducerTags.InvokeRunner tag)
            => Root.Eval(x,
                Id().Then(() =>
                {
                    const char RS = (char)30;
                    const char EOM = (char)25;

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
                }));
        
        public Cont<X, Bind[]> Match(X x, DeducerTags.GetUserPins tag)
            => Root.Eval(x,
                Id().Then(() =>
                {
                    const char RS = (char)30;
                    const char EOM = (char)25;

                    return Say(
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
                }));

        
        static (string?, string?) Split2(string str)
        {
            var parts = str.Split(" ", 2, StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
            return (parts.ElementAtOrDefault(0), parts.ElementAtOrDefault(1));
        }
    }
}