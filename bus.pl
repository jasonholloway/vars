#!/usr/bin/env perl
use strict;
use warnings;
use 5.034;
no warnings 'experimental';

use lib $ENV{VARS_PATH};
use Data::Dumper;
use IO::Select;

my $log = $ENV{VARS_DEBUG} ? *STDERR : 0;

my $root = new Peer($log, 'root', *STDOUT, *STDIN);
my @convs = ({ from => $root, to => $root });
my %clamp;
my @tasks;

my @peers = (
	$root,
	map { Peer::fromSpec($log, $_) } split(';',$ARGV[0])
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

	Select: while(my @handles = $select->can_read()) {
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

				if($p->{alias} eq "root") {
					last Select;
					return;
				}
				else {
				}
			}
		}
	}

	foreach my $p (@peers) {
		$p->close();
	}
}

sub lg {
	my $str = shift;
	if($log && defined($str)) {
		print $log "$str\n";
	}
}


main();



package Peer;

use IPC::Open3;
use Data::Dumper;

sub new {
	my $class = shift;
  my $log = shift;
	my $alias = shift;
	my $send = shift;
	my $return = shift;
	my $pid = shift;

	my $me = {
		alias => $alias,
		send => $send,
		return => $return,
		pid => $pid,
    log => $log,
		buffer => '',
		lines => [],
		targets => []
	};

	bless $me, $class;

	$me
}

sub lg {
  my $me = shift;
	my $s = shift;

  if($me->{log}) {
    my $h = $me->{log};
    print $h "$s\n";
  }
}

sub fromSpec {
  my $log = shift;
	my $raw = shift;
	my ($alias, $cmd) = split(':', $raw);

	my $pid = open3(my $send, my $return, '>&STDERR', $cmd) or die "Couldn't run $cmd";

	new Peer($log, $alias, $send, $return, $pid);
}


sub pushTarget {
	my $me = shift;
	my $target = shift;
	unshift(@{$me->{targets}}, $target);
	# $me->lg("[$me->{alias}] push $target->{alias}");
}

sub popTarget {
	my $me = shift;
	my $old = shift(@{$me->{targets}});
	# $me->lg("[$me->{alias}] popped $old->{alias}");
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
		# $me->lg("HANDLE [$me->{alias}...] $line");
		if($line =~ /^@(?<cmd>[A-Z]+) ?(?<rest>.*)/) {
			# $me->lg('cmd $' . $+{cmd});
			return ($+{cmd}, $+{rest});
		}
		elsif(defined(my $target = $me->{targets}[0])) {
			# $me->lg('relay');
			$target->say($me->{alias}, $line);
		}
	}

	()
}


sub close {
	my $me = shift;

	close($me->{send}); #or die "Can't close...";
	close($me->{return}); #or die "Can't close...";

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

  if($me->{log}) {
    my $lh = $me->{log};
    print $lh "[$src -> $me->{alias}] $line\n";
  }
}


	# the runner should have an optional pty
	# so different scripts can run in slightly different contexts (instead of always being interactive by default)
	# so with the tty flag the runner makes a pty available
	# more than that - it mans all input must be streamed through the pty
	# 
	# and then the pty must be multiplexed somehow
	# we either present many at once, or - more simply - we do some kind of locking serialization of sessions
	# either way, a pty must be requested by the root from some central place
	#
	# - Runner requesty PTY
	# - PTY deets are served back
	# - PTY provides unmediated input and output
	#
	# but locking on the PTY - it's useless if we disallow other PTY uses as soon as a block begins
	# as the interactive blocks are precisely the ones we want to sometimes preempt
	#
	# BUT it's not just the PTY, it's STDERR as well requiring synchronization
	# if we have a PTY on the go, we want to block STDERR for a bit
	# everything in fact goes to STDERR, which is what we actually want to synchronize
	#
	# at the top level, we have PTYs and a one-way output Pipe, both wanting to write to STDERR
	# the PTYs have precedence, as soon as one gets going, it claims the output
	# as such, the pipe is effectively a default; given nothing else, let's listen to that
	#
	# additionally a PTY should only really lock the output on its first i/o (could even just be its first bytes out for simplicity)
	# 
	# whatever is doing the pumping of the PTYs needs to be in a 'proper' language
	# and it could even be an additional module...
	# the runner asks this other module for a PTY
	# similarly root asks for a PTY when suggesting
	# and a pipe for streaming output
	# so all runtime i/o goes via this other module
	#
	
