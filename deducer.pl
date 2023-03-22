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
                my %x = readInputs();
                $x{scopes} = [ {} ];
                $x{pins} = readUserPins();

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
    my $x = shift;
    my $target = shift;
    my $block = $x->{blocks}{$target};

    if(grep(/P/, @{$block->{flags}})) {
        say '@ASK files';
        say "pins $target";
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

    foreach my $in (@{$block->{ins} or []}) { #todo synthetic blocks won't as is appear in blocks
        my $vn = $in->{name};
        my $v = summonVar($x, $vn);

        my $vals = $v->{vals};
        
        if($in->{single} and scalar(@{$vals}) != 1) {
            say "pick $vn ¦".join('¦', @{$v->{vals}});
            say '@YIELD';
            hear() =~ /^(?<val>.*?)(?<pin>\!?)$/;

            if($+{pin}) {
                say "pin $vn $+{val}";
            }

            addVar($x, $vn, [$+{val}], "picked"); # todo this sets rather than adds - narrows
        }
        
        $boundIns{$vn} = $v;
    }

    say '@ASK runner';
    say "run @{$block->{flags}}\031$block->{outline}";

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
    
    my %boundOuts;

    while(my $line = hear()) {
        given($line) {
            when(/^bind (?<vn>[^ ]+) (?<val>.+)/) {
                my $v = decode($+{val});
                my @vs = split(/¦/, $v);

                #todo surely vars sent to runner need to be encoded?
                #tho this should be done by runner
                push(@{$boundOuts{$+{vn}} //= []}, @vs);
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

    # if addVar appended to disjunctions
    # then we wouldn't need boundOuts

    foreach my $vn (keys %boundOuts) {
        my @vs = @{$boundOuts{$vn}};
        addVar($x, $vn, \@vs, $target);
    }
}

sub summonVar {
    my $x = shift;
    my $vn = shift;

    getVar($x, $vn)
        or tryPinned($x, $vn)
        or do {
            foreach my $source (@{$x->{supplying}{$vn} or []}) {
                evalBlock($x, $source);
                #on overlap, don't overwrite but add
            }
            getVar($x, $vn);

        } or askVar($x, $vn);
}

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

sub addVar {
    my $x = shift;
    my $vn = shift;
    my $vals = shift;
    my $source = shift;

    #should merge vals and sources
    my $scope = $x->{scopes}[0];
    my $v = $scope->{$vn} //= {};

    $v->{vals} = $vals;
    $v->{source} = $source; # todo should be source per val

    say "bound $source $vn " . join('¦', @{$vals});

    $v;
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
    my $val = hear();

    addVar($x, $vn, [ $val ], 'asked');
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
        if(exists $blocks->{$targetName}) {
            $targets{$targetName} = 1;
        }
        elsif(exists $blocksByName{$targetName}) {
            my $bid = $blocksByName{$targetName}{bid};
            $targets{$bid} = 1;
        }
    }
    
    (
        blocks => $blocks,
        targets => { %targets },
        flags => [ hearWords() ],
        supplying => { %supplying },
    );
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

    if($bid =~ /^get:(?<vn>.+)/) {
        $ins = $+{vn};
    }

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

    $raw =~ /(?<name>.+?)(?<postfix>[\*]?)$/;
    $v{name} = $+{name};

    if(!$+{postfix}) {
        $v{single} = 1;
    }
    
    \%v;
}

sub readUserPins {
    my %ac;

    while(my $path = glob("$ENV{HOME}/.vars/pinned/*")) {
        $path =~ /(?<vn>[^\/]+)$/;
        my $vn = $+{vn};

        $ac{$vn} = {
            path => $path
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

sub decode {
    my $s = shift;
    $s =~ s/\36/\n/;
    $s
}

main();
