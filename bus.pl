#!/usr/bin/perl
use strict;
use warnings;
use 5.034;
no warnings 'experimental';

use lib $ENV{VARS_PATH};
use Data::Dumper;
use IO::Select;

my $debug = $ENV{VARS_DEBUG};

my $root = new Peer('root', *STDOUT, *STDIN);
my @convs = ({ from => $root, to => $root });
my %clamp;

my @peers = (
  $root,
  map { Peer::fromSpec($_) } split(';',$ARGV[0])
  );

my %peersByAlias;
foreach my $peer (@peers) {
  $peersByAlias{$peer->{alias}} = $peer;
}

my %peersByHandle;
foreach my $peer (@peers) {
  $peersByHandle{$peer->{return}} = $peer;
}

$SIG{'TERM'} = sub {
  foreach my $p (@peers) {
    $p->close();
  }
  exit;
};

my $FIN = 0;
my $REPUMP = 1;
my $CONT = 2;

sub lg {
  my $str = shift;
  print STDERR "$str\n";
}

sub pump {
  my $p = shift;

  lg("[$p->{alias}] ...");
  my ($bytes, $lines) = $p->pump();
  if($bytes == 0) { return ($FIN, $p); }
  # lg("Pumped $lines from $p->{alias}");

  # we're getting stuck pumping from root
  # presumably because END isn't getting properly treated

  if($lines > 0) {
    my $from = $convs[0]{from};
    my $to = $convs[0]{to};

    if($p == $from) {
      while(my ($cmd,$arg) = relay($from, $to, 1)) {
        given($cmd) {
          when('ASK') {
            $to = $peersByAlias{$arg} or die "Referred to unknown peer $arg";
            unshift(@convs, { from => $from, to => $to });
          }
          when('YIELD') {
            my $tmp = $from;
            $convs[0]{from} = $from = $to;
            $convs[0]{to} = $to = $tmp;
            return ($REPUMP, $from);
          }
          when('CLAMP') {
            $clamp{from} = $to;
            $clamp{to} = $from;
            $clamp{tag} = $arg;
            return ($REPUMP, $to);
          }
          when('UNCLAMP') {
            %clamp = ();
          }
          when('END') {
            if(defined(shift(@convs))) {
              $from = $convs[0]{from};
              $to = $convs[0]{to};
            }
            else {
              lg("END");
              return ($FIN, $p);
            }
          }
          when('ERROR') {
            die "Error bubbled: $arg";
          }
          default {
            die "unknown cmd $cmd";
          }
        }
      }
    }
    elsif($clamp{from} && $p == $clamp{from}) {
      relay($p, $clamp{to}, 0);
    }

    return ();
  }
}

sub main {
  my $select = new IO::Select(map { $_->{return} } @peers);

  while(my @handles = $select->can_read()) {
    my ($cmd, $arg);

    foreach my $h (@handles) {
      my $p = $peersByHandle{$h};
      ($cmd, $arg) = pump($p);

    start:
      given($cmd) {
        when($FIN) {
          $select->remove($arg);

          if($arg eq *STDIN) { return; }
          else { next; }
        }
        when($REPUMP) {
          ($cmd, $arg) = pump($arg);
          goto start;
        }
        default {

        }
      }
    }
  }
}

my %knownCmds = (
  ASK => 1,
  YIELD => 1,
  END => 1,
  ERROR => 1,
  CLAMP => 1
);

sub relay {
  my $from = shift;
  my $to = shift;
  my $allowCmds = shift;

  $_ = { from => $from, to => $to };

  while(defined(my $line = shift(@{$from->{lines}}))) {
    if($line =~ /^@(?<cmd>\w+) ?(?<rest>.*)/ && defined($knownCmds{$+{cmd}})) {
      print STDERR "[$from->{alias}] $line\n" if $debug;
      die "Can't send a command unless conversation leader!" unless $allowCmds;
      return ($+{cmd}, $+{rest});
    }
    else {
      $to->say($line);
    }
  }

  ();
}

main();


package Peer;

use IPC::Open3;
use Data::Dumper;

sub new {
  my $class = shift;
  my $alias = shift;
  my $send = shift;
  my $return = shift;
  my $pid = shift;

  my $me = {
    alias => $alias,
    send => $send,
    return => $return,
    pid => $pid,
    buffer => '',
    lines => []
  };

  bless $me, $class;

  $me
}

sub fromSpec {
  my $raw = shift;
  my ($alias, $cmd) = split(':', $raw);

	my $pid = open3(my $send, my $return, '>&STDERR', $cmd) or die "Couldn't run $cmd";

  new Peer($alias, $send, $return, $pid);
}

sub pump {
  my $me = shift;
  
  defined(my $c = sysread($me->{return}, $me->{buffer}, 4096, length($me->{buffer}))) or die "Problem reading $me->{alias}: $!";

  while($me->{buffer} =~ /^(?<line>[^\n]*)\n(?<rest>[\s\S]*)$/m) {
    push(@{$me->{lines}}, $+{line});
    $me->{buffer} = $+{rest};
  }

  ($c, scalar @{$me->{lines}})
}

sub close {
  my $me = shift;

  close($me->{send}) or die "Can't close...";
  close($me->{return}) or die "Can't close...";

  my $pid = $me->{pid};
  if(defined($pid)) {
    print STDERR "KILL $pid! \n";
    kill 'TERM', $pid or die "Can't kill $pid...";
  }
}

sub say {
  my $me = shift;
  my $line = shift;

  my $h = $me->{send};

  print $h $line . "\n";
  $h->flush();
  print STDERR "[$_->{from}{alias} -> $me->{alias}] $line\n" if $debug;
}

