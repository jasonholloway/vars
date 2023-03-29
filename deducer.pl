#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use MIME::Base64 qw( decode_base64 );
use 5.034;
no warnings 'experimental';

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

                foreach my $target (keys %{$x{targets}}) {
                    evalBlock(\%x, $target);
                }

                say 'fin';
            }
        }
        say '@YIELD';
    }
}

# slight problem with pending not being ordered: means its not programmable

sub evalBlock {
    my $x = shift;
    my $target = shift;
    my $block = $x->{blocks}{$target};
    my $ins;

    if($target =~ /^get:(?<vn>.+)/) {
      $ins = [{ alias => $+{vn}, from => [{ name => $+{vn} }] }];
    }
    else {
      say '@ASK files';
      say "ins $target";
      say '@YIELD';
      my $rawIns = hear();
      $ins = Sig::parse($rawIns);
      say '@END';
    }

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

    foreach my $in (@{$ins}) { #todo synthetic blocks won't as is appear in blocks
        my $alias = $in->{alias};

        foreach my $source (@{$in->{from}}) {
          my $vn = $source->{name};
          my $pins = $source->{pins};

          if($pins) {
            pushScope($x);
            foreach my $pvn (keys %{$pins}) {
              addVar($x, $pvn, [$pins->{$pvn}[0]], "pinned") # all pins need enumerating
            }
          }

          my $v = summonVar($x, $vn);

          my $vals = $v->{vals};
          my $mod = $in->{modifier};

          if($mod and $mod ne '*' and scalar(@{$vals}) != 1) {
              say "pick $alias ¦".join('¦', @{$v->{vals}});
              say '@YIELD';
              hear() =~ /^(?<val>.*?)(?<pin>\!?)$/;

              if($+{pin}) {
                  say "pin $alias $+{val}";
              }

              $v = addVar($x, $alias, [$+{val}], "picked");
          }

          if($pins) {
            popScope($x);
            # my $curr = $x->{scopes}[-1];

            # if(!exists($curr->{$alias})) {
            #   $curr->{$alias} = {};
            # }

            # push(@{$curr->{$alias}{vals}}, @{$popped->{vn}{vals}});
            # $curr->{$alias}{source} = $popped->{vn}{source};
          }

          # if(!exists($boundIns{$alias})) {
          #   $boundIns{$alias} = {};
          # }

          push(@{($boundIns{$alias} //= {})->{vals}}, @{$v->{vals}});
          # lg(Dumper(\%boundIns));
        }
    }

    say '@ASK runner';
    say "run @{$block->{flags}}\031$block->{outline}";

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
    my ($bid, $names, $outs, $flags) = split(';',$outline);

    # if($bid =~ /^get:(?<vn>.+)/) {
    #     $ins = $+{vn};
    # }

    # lg($ins);

    {
        bid => $bid,
        names => [ split(',',$names // '') ],
        # ins => Sig::parse($ins),
        outs => [ map {readVar($_)} split(',',$outs // '') ],
        flags => [ split(',',$flags // '') ],
        outline => $outline
    }
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
