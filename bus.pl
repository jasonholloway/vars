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


sub main {
  my $select = new IO::Select(map { $_->{return} } @peers);

  readLoop: while(my @handles = $select->can_read()) {
    handleLoop: foreach my $h (@handles) {
      my $p = $peersByHandle{$h};
      my ($bytes, $lines) = $p->pump();

      if($bytes == 0) {
        $select->remove($h);

        if($h eq *STDIN) { last readLoop; }
        else { next handleLoop; }
      }

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
              }
              when('END') {
                shift(@convs);
                $from = $convs[0]{from};
                $to = $convs[0]{to};
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
      }
    }
  }
}

my %knownCmds = (
  ASK => 1,
  YIELD => 1,
  END => 1,
  ERROR => 1
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

  my $me = {
    alias => $alias,
    send => $send,
    return => $return,
    buffer => '',
    lines => []
  };

  bless $me, $class;

  $me
}

sub fromSpec {
  my $raw = shift;
  my ($alias, $cmd) = split(':', $raw);

	open3(my $send, my $return, '>&STDERR', $cmd) or die "Couldn't run $cmd";
  #todo capture pid

  new Peer($alias, $send, $return);
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

sub say {
  my $me = shift;
  my $line = shift;

  my $h = $me->{send};

  print $h $line . "\n";
  $h->flush();
  print STDERR "[$_->{from}{alias} -> $me->{alias}] $line\n" if $debug;
}

