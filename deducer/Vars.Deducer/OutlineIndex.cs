using System.Collections;
using System.Collections.Generic;
using System.Linq;
using Vars.Deducer.Model;

namespace Vars.Deducer
{
    public class OutlineIndex : IEnumerable<Outline>
    {
        readonly OutlineSynthesizer _synth;

        readonly Outline[] _outlines;
        readonly ILookup<string, Outline> _byOutput;
        readonly ILookup<string, Outline> _byName;

        public OutlineIndex(IEnumerable<Outline> outlines)
        {
            _synth = new OutlineSynthesizer();
            
            _outlines = outlines.ToArray();
            
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
        
        // the index is materializing a full tree for us
        // even though really we'd want this to be a lattice-like
        // it's like really the index should be serving BlockRefs
        // these BlockRefs can then be compared
        // so - not just the planner doing this
        
        //the planner would summon a link, and then summon child links as it saw fit
        //index then selects an outline that matches the target
        //
        //again - we don't want a tree, but a lattice, so bundling upstreams with the downstream don't work
        //
        // TODO serve single TargetLinks here
        // it's up to the planner to recurse
        //
        
        
        public TargetLink SummonLink(Target target)
        {
            var blocks = (
                from block in SummonOutlines(target)
                select block
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