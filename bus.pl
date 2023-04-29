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
  lg('TERM!!!');
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
	readFromAll(\@handles);

    while(defined(my $task = shift(@tasks))) {
      my ($cmd, $arg) = @{$task};
      given($cmd) {
        when($PUMP) {
          pump($arg);
        }
        when($RELAY) {
          my ($from, $to, $tag) = @{$arg};
          relay($from, $to, 0, $tag);
        }
		when($FIN) {
		  my $h = $arg->{return};
		  $select->remove(($h));
		  if($arg->{alias} eq 'root') {
			return;
		  }
		}
      }
    }
  }
}

sub readFromAll {
  my $handles = shift;

  foreach my $h (@{$handles}) {
	my $p = $peersByHandle{$h};
	lg("[$p->{alias}] ...");
	my ($bc, $lc) = $p->read();

	if($lc > 0) {
	  push(@tasks, [$PUMP, $p]);
	}

	if($bc == 0) {
	  push(@tasks, [$FIN, $p]);
	}
  }


}

sub pump {
  my $p = shift;

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
          push(@tasks, [$PUMP, $from]);
        }
        when('CLAMP') {
          $clamp{from} = $to;
          $clamp{to} = $from;
          $clamp{tag} = $arg;
          push(@tasks, [$RELAY, [$to, $from, $arg]]);
          push(@tasks, [$PUMP, $p]);
          return;
        }
        when('UNCLAMP') {
		  my $tag = $clamp{tag};
          %clamp = ();
		  $from->say(".", "-$tag");
        }
        when('END') {
          if(defined(shift(@convs))) {
            $from = $convs[0]{from};
            $to = $convs[0]{to};
          }
          else { exit; }
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
    relay($p, $clamp{to}, 0, $clamp{tag});
  }
}

my %knownCmds = (
  ASK => 1,
  YIELD => 1,
  END => 1,
  ERROR => 1,
  CLAMP => 1,
  UNCLAMP => 1
);

sub relay {
  my $from = shift;
  my $to = shift;
  my $allowCmds = shift;
  my $tag = shift;

  $_ = { from => $from, to => $to };

  while(defined(my $line = shift(@{$from->{lines}}))) {
    if($line =~ /^@(?<cmd>\w+) ?(?<rest>.*)/ && defined($knownCmds{$+{cmd}})) {
      # print STDERR "[$from->{alias}] $line\n" if $debug;
      die "Can't send a command unless conversation leader!" unless $allowCmds;
      return ($+{cmd}, $+{rest});
    }
	elsif(defined($tag)) {
	  $to->say($from->{alias}, "+$tag " . $line);
	}
    else {
      $to->say($from->{alias}, $line);
    }
  }

  ();
}

sub lg {
  my $str = shift;
  print STDERR "$str\n" if $debug;
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

sub read {
  my $me = shift;
  
  defined(my $c = sysread($me->{return}, $me->{buffer}, 4096, length($me->{buffer}))) or die "Problem reading $me->{alias}: $!";

  while($me->{buffer} =~ /^(?<line>[^\n]*)\n(?<rest>[\s\S]*)$/m) {
    push(@{$me->{lines}}, $+{line});
    # lg("[$me->{alias}...] $+{line}");
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

