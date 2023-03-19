#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use MIME::Base64 qw( decode_base64 );
use 5.034;
no warnings 'experimental';

$|++;

sub main {
    while (my $line = hear()) {
        given($line) {
            when("deduce") {
                my %x = (
                    %{ readInputs() },
                    scopes => [ readUserPins() ]
                    );

                # lg("+++++ X:");
                # lg(Dumper(\%x));

                foreach my $target (keys %{$x{targets}}) {
                    evalBlock(\%x, $target);
                }

                say 'fin';
            }
        }
        
        say '@YIELD';
    }
}

# owner dog{breed="doberman"} cat{breed="persian"}
# would do the trick, as owner will already have been fixed up top
# the sequencing then matters - common vars should be listed first

# simple stuff first: deduce without scopes
# slight problem with pending not being ordered: means its not programmable

sub evalBlock {
    my %x = %{$_[0]};
    my $target = $_[1];
    my %block = %{$x{blocks}{$target}};

    my %boundIns;

    #todo pins fix var in scope here

    foreach my $in (@{$block{ins} or []}) { #todo synthetic blocks won't as is appear in blocks
        my $vn = $in->{name};
        my $v = summonVar(\%x, $vn);

        if($in->{single} and @{$v->{vals}} > 1) {
            say "pick $vn ¦".join('¦', @{$v->{vals}});
            say '@YIELD';
            hear() =~ /^(?<val>.*?)(?<pin>\!?)$/;

            if($+{pin}) {
                say "pin $vn $+{val}";
            }

            addVar(\%x, $vn, [$+{val}], "picked"); # todo this sets rather than adds - narrows
            say "bound picked $vn $+{val}"
        }
        
        $boundIns{$vn} = $v;
    }

    say '@ASK runner';
    say "run @{$block{flags}}\031$block{outline}";

    foreach my $vn (keys %boundIns) {
        my %v = %{$boundIns{$vn}};
        foreach my $val (@{$v{vals}}) {
            say "val $vn $val"
        }
    }

    say 'go';
    say '@YIELD';
    say '@END';

    # we collect individual binds into sets via boundOuts
    # then communicate these steps up the stack
    # shouldn't this again be the responsibility of the runner?
    #
    
    
    my %boundOuts;

    while(my $line = hear()) {
        given($line) {
            when(/^bind (?<vn>[^ ]+) (?<val>.+)/) {
                # todo decode
    #           decode v v

                #todo surely vars sent to runner need to be encoded?
                #tho this should be done by runner
                push(@{$boundOuts{$+{vn}} //= []}, $+{val});
            }
            when(/^set (?<name>[^ ]+) (?<val>.+)/) {
                lg("SET $+{vn} to be $+{val}");
    #           attrs[$n]="$v"
                #...
            }
            when('fin') { last }
            default { say $line }
        }
    }

    foreach my $vn (keys %boundOuts) {
        my @vs = @{$boundOuts{$vn}};
        addVar(\%x, $vn, \@vs, $target);

        my $vals = join('¦', @vs);
        say "bound $target $vn $vals";
    }
}

# sometimes we want to narrow
# sometimes we want to add
# 
#
#

sub summonVar {
    my $x = shift;
    my $vn = shift;

    getVar($x, $vn) or do {
        foreach my $source (@{$x->{supplying}{$vn} or []}) {
            evalBlock($x, $source);
            #on overlap, don't overwrite but add
        }

        getVar($x, $vn);

    } or askVar($x, $vn);
}

sub addVar {
    my $x = shift;
    my $vn = shift;
    my $vals = shift;
    my $source = shift;

    #should merge vals and sources
    my $scope = $x->{scopes}[0];
    $scope->{$vn}{vals} = $vals;
    $scope->{$vn}{source} = $source; # todo should be source per val
}

sub getVar {
    my $x = shift;
    my $vn = shift;

    foreach my $scope (@{$x->{scopes}}) {
        if(exists($scope->{$vn})) {
            return $scope->{$vn};
        }
    }
}

sub askVar {
    my $x = shift;
    my $vn = shift;

    say "dredge $vn";
    say '@YIELD';

    my $dredged = hear();
    $dredged =~ s/^¦//;

    $x->{scopes}[0]{$vn} = {
        vals => [ split(/¦/, $dredged) ],
        source => "Dredged"
    };
}

sub readInputs {
    my $blocks = readBlocks();

    my %blocksByName;
    my %supplying;
    foreach my $bid (keys %$blocks) {
        my $block = $blocks->{$bid};

        foreach my $name (@{$block->{names}}) {
            $blocksByName{$name} = $block;
        }

        foreach my $out (@{$block->{outs}}) {
            push(@{$supplying{$out->{name}}}, $bid);
        }
    }

    # should receive single target _outline_
    # this would allow us to inject in get:blah from outside
    # meaning we don't have to synthesize here

    my %targets;
    foreach my $targetName (hearWords()) {
        if(exists $blocksByName{$targetName}) {
            my $bid = $blocksByName{$targetName}{bid};
            $targets{$bid} = 1;
        }
    }
    
    {
        blocks => $blocks,
        targets => { %targets },
        flags => [ hearWords() ],
        supplying => { %supplying },
    };
}

sub readBlocks {
    my %ac;

    foreach my $block (map {readBlock($_)} hearWords()) {
        $ac{$block->{bid}} = $block;
    }
    
    \%ac;
}

sub readBlock {
    my $outline = $_[0];
    my ($bid, $names, $ins, $outs, $flags) = split(';',$outline);
    {
        bid => $bid,
        names => [ split(',',$names // '') ],
        ins => [ map {readVar($_)} split(',',$ins // '') ],
        outs => [ map {readVar($_)} split(',',$outs // '') ],
        flags => [ split(',',$flags // '') ],
        outline => $outline
    };
}

sub readVar {
    my $raw = $_[0];
    my %v;

    $raw =~ /(?<name>.+)(?<postfix>[\*]?)$/;
    $v{name} = $+{name};

    if(!$+{postfix}) {
        $v{single} = 1;
    }
    
    \%v;
}

sub readUserPins {
    my %ac;
    # below could be supplied lazily...
    while(my $file = glob("$ENV{HOME}/.vars/pinned/*")) {
        open FILE,$file or die "Failed to open $file";
        chomp(my $rawVals = decode_base64 <FILE>);
        close FILE;

        $file =~ /(?<vn>[^\/]+)$/;
        my $vn = $+{vn};
        $vn =~ s/^¦//;
        
        $ac{$vn} = {
            vals => [ split(/¦/, $rawVals) ],
            source => "pinned"
        };
    }

    \%ac;
}

sub hearWords {
    return split(' ', hear());
}

sub hear {
  start:
    chomp(my $line = <STDIN> || '');
    given($line) {
        when('@PUMP') {
            say '@PUMP';
            goto start;
        }
        default {
            return $line;
        }
    }
}

sub lg {
    my ($line) = @_;
    print STDERR "$line\n";
}

main();
