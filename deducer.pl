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
                    scopes => [{ readUserPins() }]
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

        # todo if single, pick here...
        # (tho would be nice if was simplified in runner)
        
        $boundIns{$vn} = $v;
    }

    say '@ASK runner';
    say "run @{$block{flags}}\031$block{outline}";

    foreach my $vn (keys %boundIns) {
        my %v = %{$boundIns{$vn}};

        my $rawVal = $v{val};
        $rawVal =~ s/^¦//; #todo this should be sanitised up front

        my @vals = split(/¦/, $rawVal);
        foreach my $val (@vals) {
            say "val $vn $val"
        }
    }

    say 'go';
    say '@YIELD';
    say '@END';

    while(my $line = hear()) {
        given($line) {
            when(/^bind (?<vn>[^ ]+) (?<val>.+)/) {
                lg("BIND $+{vn} to be $+{val}");
    #           decode v v
    #           boundOuts[$vn]="${boundOuts[$vn]}¦${v#¦}"
                #...
                #todo surely vars sent to runner need to be encoded?
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

    # for vn in ${!boundOuts[*]}; do
    #   v=${boundOuts[$vn]}
    #   v=${v#¦}
    #   binds[$vn]=$v
    #   say "bound $bid $vn ${v//$'\n'/$'\60'}"
    # done

    #todo blurt to context file here

    # lg(Dumper([ $target, \%boundIns ]));
}

sub summonVar {
    my %x = %{$_[0]};
    my $vn = $_[1];

    scopeBind(\%x, $vn) or do {

        foreach my $source (@{$x{supplying}{$vn} or []}) {
            evalBlock(\%x, $source);
            #on overlap, don't overwrite but add
        }

        scopeBind(\%x, $vn);

    } or askVar(\%x, $vn);
}

sub scopeBind {
    my %x = %{$_[0]};
    my $vn = $_[1];

    foreach my $scope (@{$x{scopes}}) {
        if(exists($scope->{$vn})) {
            return $scope->{$vn};
        }
    }
}

sub askVar {
    my %x = %{$_[0]};
    my $vn = $_[1];

    $x{scopes}[0]{$vn} = {
        val => "BLAH",
        source => "Dummy"
    };
}

sub readInputs {
    my %blocks = readBlocks();

    my %blocksByName;
    my %supplying;
    foreach my $bid (keys %blocks) {
        my $block = $blocks{$bid};

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
        blocks => { %blocks },
        targets => { %targets },
        flags => [ hearWords() ],
        blocksByName => { %blocksByName },
        supplying => { %supplying },
    };
}

sub readBlocks {
    my %ac;
    foreach my $block (map {readBlock($_)} hearWords()) {
        $ac{$block->{bid}} = $block;
    }
    %ac;
}

sub readBlock {
    my $outline = $_[0];
    my ($bid, $names, $ins, $outs, $flags) = split(';',$outline);
    {
        bid => $bid,
        names => [ split(',',$names || '') ],
        ins => [ map {readVar($_)} split(',',$ins || '') ],
        outs => [ map {readVar($_)} split(',',$outs || '') ],
        flags => [ split(',',$flags || '') ],
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
        chomp(my $val = decode_base64 <FILE>);
        close FILE;

        $file =~ /(?<vn>[^\/]+)$/;
        $ac{$+{vn}} = {
            val => $val,
            source => "pinned"
        };
    }

    %ac;
}

sub trimBlocks {
    my %x = %{$_[0]};

    my %trimmables;
    foreach my $bid (keys %{$x{blocks}}) {
        $trimmables{$bid} = 1;
    } 

    my %pending;
    foreach my $bid (keys %{$x{targets}}) {
        delete $trimmables{$bid};

        foreach my $vn (@{$x{blocks}{$bid}{ins}}) {
            #TODO vns need to be trimmed
            $pending{$vn} = 1;
        }
    }

    my %seen;
    while(keys %pending) {
        foreach my $pvn (keys %pending) {
            if(exists($x{pinned}{$pvn})) {
                continue
            };

            foreach my $bid (@{$x{supplying}{$pvn}}) {
                delete $trimmables{$bid};

                foreach my $ivn (@{$x{blocks}{$bid}{ins}}) {
                    #TODO trim vn
                    if(!exists($seen{$ivn})) {
                        $pending{$ivn} = 1;
                    }
                }
            }

            $seen{$pvn} = 1;
            delete $pending{$pvn};
        }
    }

    foreach my $bid (keys %trimmables) {
        delete $x{blocks}{$bid};
    }
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
