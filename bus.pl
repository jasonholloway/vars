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
my @tasks;

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
  # lg('TERM!!!');
  foreach my $p (@peers) {
    $p->close();
  }
  exit;
};

my $PUMP = 1;
my $RELAY = 2;
my $FIN = 3;

sub main {
  my $select = new IO::Select(map { $_->{return} } @peers);

  while(my @handles = $select->can_read()) {
    foreach my $h (@handles) {
      my $p = $peersByHandle{$h};

      # lg("[$p->{alias}] ...");
      my ($bc, $lc) = $p->read();

      if($lc > 0) {
        while(my @r = $p->handle()) {
          my ($cmd, $arg) = @r;

          given($cmd) {
            when('ASK') {
              my $to = $peersByAlias{$arg} or die "Referred to unknown peer $arg";
              $p->pushTarget($to);
              $to->pushTarget($p);
            }
            when('END') {
              $p->popTarget();
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

      if($bc == 0) {
        $select->remove(($h));
        return if($p->{alias} eq 'root');
      }
    }
  }
}

sub lg {
  my $str = shift;
  if(defined($str)) {
	print STDERR "$str\n" if $debug;
  }
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
    lines => [],
    targets => []
  };

  bless $me, $class;

  $me
}

sub lg {
  my $s = shift;
  print STDERR "$s\n";
}

sub fromSpec {
  my $raw = shift;
  my ($alias, $cmd) = split(':', $raw);

  my $pid = open3(my $send, my $return, '>&STDERR', $cmd) or die "Couldn't run $cmd";

  new Peer($alias, $send, $return, $pid);
}


sub pushTarget {
  my $me = shift;
  my $target = shift;
  unshift(@{$me->{targets}}, $target);
  # lg("[$me->{alias}] push $target->{alias}");
}

sub popTarget {
  my $me = shift;
  my $old = shift(@{$me->{targets}});
  # lg("[$me->{alias}] popped $old->{alias}");
}


sub read {
  my $me = shift;

  # TODO what about for blocks greater than 4kb??!?!

  if(defined(my $c = sysread($me->{return}, $me->{buffer}, 4096, length($me->{buffer})))) {
    while($me->{buffer} =~ /^(?<line>[^\n]*)\n(?<rest>[\s\S]*)$/m) {
      push(@{$me->{lines}}, $+{line});
      $me->{buffer} = $+{rest};
    }

    ($c, scalar @{$me->{lines}})
  }
  else {
    die "Problem reading $me->{alias}: $!";
  }
}

sub handle {
  my $me = shift;
  my $lines = $me->{lines};

  while(defined(my $line = shift(@$lines))) {
    # lg("HANDLE [$me->{alias}...] $line");
    if($line =~ /^@(?<cmd>[A-Z]+) ?(?<rest>.*)/) {
      # lg('cmd $' . $+{cmd});
      return ($+{cmd}, $+{rest});
    }
    elsif(defined(my $target = $me->{targets}[0])) {
      # lg('relay');
      $target->say($me->{alias}, $line);
    }
  }

  ()
}


sub close {
  my $me = shift;

  close($me->{send}) or die "Can't close...";
  close($me->{return}) or die "Can't close...";

  my $pid = $me->{pid};
  if(defined($pid)) {
    # print STDERR "KILL $pid! \n";
    kill 'TERM', $pid or die "Can't kill $pid...";
  }
}

sub say {
  my $me = shift;
  my $src = shift;
  my $line = shift;

  my $h = $me->{send};

  print $h $line . "\n";
  $h->flush();
  print STDERR "[$src -> $me->{alias}] $line\n" if $debug;
}

