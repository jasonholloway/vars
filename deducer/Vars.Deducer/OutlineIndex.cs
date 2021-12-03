using System.Collections;
using System.Collections.Generic;
using System.Linq;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    public class OutlineIndex : IEnumerable<Outline>
    {
        readonly OutlineSynthesizer _synth;
        private readonly Outline[] _outlines;
        readonly ILookup<string, Outline> _byOutput;
        readonly ILookup<string, Outline> _byName;

        public OutlineIndex(IEnumerable<Outline> outlines)
        {
            _synth = new OutlineSynthesizer();
            _outlines = outlines
                .ToArray();
            
            _byOutput = (
                from ol in _outlines
                from outp in ol.Outputs
                select (VarName: outp.Name, Outline: ol)
            ).ToLookup(t => t.VarName, t => t.Outline);
            
            _byName = (
                from ol in _outlines
                from name in ol.Names
                select (BlockName: name, Outline: ol)
            ).ToLookup(t => t.BlockName, t => t.Outline);
        }

        public OutlineIndex(params Outline[] outlines) : this(outlines.AsEnumerable())
        { }

        public TargetLink SummonLink(Target target)
        {
            var blocks = (
                from block in SummonOutlines(target)
                let subTargets = ( 
                        from inp in block.Inputs
                        select SummonLink(new VarTarget(inp))
                    ).ToArray()
                select new BlockLink(block, subTargets)
            ).ToArray();
            
            return new TargetLink(target, blocks);
        }

        private IEnumerable<Outline> SummonOutlines(Target target)
        {
            var found = ( 
                target switch
                {
                    VarTarget(var @var) => _byOutput[@var.Name],
                    BlockTarget(string name) => _byName[name],
                    _ => Enumerable.Empty<Outline>()
                }).ToArray();
            
            //PROBLEM
            //synthetic outlines not currently stored to index!!!!!!!

            return found.Any()
                ? found
                : _synth.Synthesize(target);
        }

        public IEnumerator<Outline> GetEnumerator()
            => _outlines.AsEnumerable().GetEnumerator();

        IEnumerator IEnumerable.GetEnumerator()
            => _outlines.GetEnumerator();
    }
}