#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use MIME::Base64 qw(decode_base64);
use List::Util qw(uniq);
use 5.034;
no warnings 'experimental';
no warnings 'deprecated';

use lib $ENV{VARS_PATH};
use Sig;

$|++;

sub main {
    while (my $line = hear()) {
        given($line) {
            when("deduce") {
                my %x = readInputs();
                $x{scopes} = [ {} ];
                $x{pins} = readUserPins();

                # if($ENV{VARS_DEBUG}) {
                #     lg(Dumper(\%x));
                # }

                foreach my $target (keys %{$x{targets}}) {
                    evalExp(\%x,
                            {
                                alias => $target,
                                from => [{
                                    name => $target,
                                    args => []
                                }]
                            },
                            "ROOT");
                }

                say 'fin';
            }
        }
        say '@YIELD';
    }
}

sub evalExp {
  my $x = shift;
  my $exp = shift;
  my $bid = shift;

  my $alias = $exp->{alias};

  my @vs;

  foreach my $source (@{$exp->{from}}) {
    my $vn0 = $source->{name};
    my $vn = join("#", $vn0, @{$source->{args}});
    my $pins = $source->{pins};

    if($pins) {
      pushScope($x);
      foreach my $pvn (keys %{$pins}) {
        addVar($x, $pvn, [$pins->{$pvn}[0]], "pinned") # all pins need enumerating
      }
    }

    my $v = summonOut($x, $vn);
    my $vals = $v->{vals};
    my $mod = $exp->{modifier};

    # lg("VALS " . Dumper(\$vals));

    # todo this should be done after processing all sources !!!!!
    if((!$mod or $mod ne '*') and scalar(@{$vals}) != 1) {
        say "pick $alias ¦".join('¦', @{$vals});
        say '@YIELD';
        hear() =~ /^(?<val>.*?)(?<pin>\!?)$/;

        if($+{pin}) {
            say "pin $alias $+{val}";
        }

        $v = putVar($x, $alias, [$+{val}], "picked");
    }

    if($pins) {
      popScope($x);
    }

    push(@vs, @{$v->{vals}});
  }

  putVar($x, $alias, \@vs, $bid);

  ($alias, \@vs)
}

sub summonOut {
    my $x = shift;
    my $vn = shift;

    # lg("TARGET: " . $vn);
    # lg(Dumper($x));
    # lg(Dumper($x->{supplying}{$target}));

    return getVar($x, $vn)
        || tryPinned($x, $vn)
        || do {
            my @bids;

            foreach my $bid (@{$x->{supplying}->{$vn}}) {
                push(@bids, $bid);
            }

            foreach my $bid (@bids) {
                evalBlock($x, $bid);
            }
            
            getVar($x, $vn)
        }
        || askVar($x, $vn);
}

sub evalBlock {
    my $x = shift;
    my $bid = shift;
    my $block = $x->{blocks}{$bid};

    if(grep(/P/, @{$block->{flags}})) {
        say '@ASK files';
        say "pins $bid";
        say '@YIELD';

        my @blockPins;

        while(my $vn = hear()) {
            if($vn =~ /fin/) { last; }

            my $val = hear();
            push(@blockPins, [ $vn, $val ]);
        }

        say '@END';

        foreach my $tup (@blockPins) {
            addVar($x, $tup->[0], [$tup->[1]], "pinned");
        }
    }

    my %boundIns;

    foreach my $in (@{$block->{ins} or []}) {
      my ($alias, $vs) = evalExp($x, $in, $bid);
      push(@{($boundIns{$alias} //= {})->{vals}}, @{$vs});
    }

    say '@ASK runner';
    say "run $block->{outline}";

    say "flags @{$block->{flags}}";


    #where to get args????
    #they are against each OUT *******

    # foreach my $arg (@{$target->{args}}) {
    #     say "arg $arg"
    # }

    foreach my $vn (keys %boundIns) {
        my $v = $boundIns{$vn};

        foreach my $val (@{$v->{vals}}) {
            say "val $vn $val"
        }
    }

    say 'go';
    say '@YIELD';
    say '@END';

    # we collect individual binds into sets via boundOuts
    # then communicate these steps up the stack
    # shouldn't this again be the responsibility of the runner?

    say "running $bid";

    my %boundOuts;
    my @linesOut = ();
    my $singleOut;

    if(scalar(@{$block->{outs}}) == 1) {
        $singleOut = $block->{outs}[0]->{name};
    }

    while(my $line = hear()) {
        given($line) {
            when(/^bind (?<vn>[^ ]+) (?<val>.+)/) {
                # my $v = decode($+{val});
                # my @vs = split(/¦/, $v);

                #todo surely vars sent to runner need to be encoded?
                #tho this should be done by runner

                my @vs = split(/¦/, $+{val});
                push(@{$boundOuts{$+{vn}} //= []}, @vs);
            }
            when(/^set (?<name>[^ ]+) (?<val>.+)/) {
                lg("SET $+{vn} to be $+{val}");
    #           attrs[$n]="$v"
                #...
            }
            when(/^out (?<line>.*)/) {
                push(@linesOut, $+{line});
            }
            when('fin') { last }
            default { say $line }
        }
    }

    foreach my $vn (keys %boundOuts) {
        my @vs = @{$boundOuts{$vn}};
        addVar($x, $vn, \@vs, $bid);
    }

    # if($singleOut and scalar(@{$boundOuts{$singleOut} // []}) == 0) {
    #     my $val = join("\n", @linesOut);
    #     addVar($x, $singleOut, [$val], $bid);
    # }
}

# so we have two summons
# one is for when we have read the block and now need to summon inputs too
# 
#
#
#
#
#
#
#





# TODO TODO TODO
# need to move more bits from below into summonOut
#
#

sub tryPinned {
    my $x = shift;
    my $vn = shift;

    if(my $pin = $x->{pins}{$vn}) {
        return $pin->{summoned} //= do {
            my $file;

            open $file,$pin->{path} or die "Failed to open $pin->{path}";
            chomp(my $rawVals = decode_base64 <$file>);
            close $file;

            addVar($x, $vn, [ split(/¦/, $rawVals) ], 'pinned');
        };
    }
}

sub pushScope {
  my $x = shift;
  push(@{$x->{scopes}}, {});
}

sub popScope {
  my $x = shift;
  pop(@{$x->{scopes}});
}

sub addVar {
    my $x = shift;
    my $vn = shift;
    my $vals = shift;
    my $source = shift;

    #should merge vals and sources
    my $scope = $x->{scopes}[-1];
    my $v = $scope->{$vn} //= {};

    push(@{$v->{vals}}, @{$vals});
    @{$v->{vals}} = uniq @{$v->{vals}};

    $v->{source} = $source; # todo should be source per val

    emitBound($vn, $vals, $source);

    $v;
}

sub putVar {
    my $x = shift;
    my $vn = shift;
    my $vals = shift;
    my $source = shift;

    #should merge vals and sources
    my $scope = $x->{scopes}[-1];
    my $v = $scope->{$vn} //= {};

    @{$v->{vals}} = @{$vals};
    $v->{source} = $source; # todo should be source per val

    emitBound($vn, $vals, $source);

    $v;
}

sub emitBound {
    my $vn = shift;
    my $vals = shift;
    my $source = shift;

    my $v = join('|', @{$vals // []});
    $v =~ tr/\n/\31/;

    say "bound $source $vn $v";
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

    say "ask $vn";
    say '@YIELD';
    my $v = hear();

    $v =~ /(?<val>.+?)(?<pin>\!?)$/;

    if($+{pin}) {
      # add to pin file... todo
    }

    addVar($x, $vn, [ $+{val} ], 'asked');
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

    my %targets;
    foreach my $tn (hearWords()) {
        $targets{$tn} = 1;
    }

    # foreach my $targetName (hearWords()) {
    #     if(exists $blocks->{$targetName}) {
    #         $targets{$targetName} = 1;
    #     }
    #     elsif(exists $blocksByName{$targetName}) {
    #         my $bid = $blocksByName{$targetName}{bid};
    #         $targets{$bid} = 1;
    #     }
    #     elsif(exists $supplying{$targetName}) {
    #         foreach my $bid (@{$supplying{$targetName}}) {
    #             $targets{$bid} = 1;
    #         }
    #     }
    # }
    
    (
        blocks => $blocks,
        targets => { %targets },
        flags => [ hearWords() ],
        supplying => { %supplying },
    );
}

sub readBlocks {
    my %ac;

    foreach my $block (map {readBlock($_)} hearWords("\030")) {
        $ac{$block->{bid}} = $block;
    }
    
    \%ac;
}

sub readBlock {
    my $outline = $_[0];
    my ($bid, $names, $ins, $outs, $flags) = split("\031",$outline);

    if($bid =~ /^get:(?<vn>.+)/) {
        $ins = $+{vn};
    }

    {
        bid => $bid,
        names => [ split(',',$names // '') ],
        ins => Sig::parse($ins),
        outs => [ map {readVar($_)} split(' ',$outs // '') ],
        flags => [ split(',',$flags // '') ],
        outline => $outline
    };
}

sub readVar {
    my $raw = $_[0];
    my %v;

    $raw =~ /(?<name>.+?)(?<postfix>[\*]?)$/;
    $v{name} = $+{name};

    if(!$+{postfix}) {
        $v{single} = 1;
    }
    
    \%v;
}

sub readUserPins {
    my %ac;

    while(my $path = glob("$ENV{HOME}/.vars/current/pinned/*")) {
        $path =~ /(?<vn>[^\/]+)$/;
        my $vn = $+{vn};

        $ac{$vn} = {
            path => $path
        };
    }

    \%ac;
}

sub hearWords {
    return split($_[0] // ' ', hear());
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

sub decode {
    my $s = shift;
    $s =~ s/\36/\n/;
    $s
}

main();
