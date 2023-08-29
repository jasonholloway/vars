#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use IO::Select;
use 5.034;
no warnings 'experimental';

use lib $ENV{VARS_PATH};
use IO::Pty;

my $tty = shift;

$|++;

sub main {
	my $inp = new Controller('inp', *STDIN);

	my $selector = new Selector;
	$selector->add($inp);

	$selector->run();
}

main();



package Selector;

sub new {
	my $class = shift;

	my $me = {};
	$me->{select} = new IO::Select;
	$me->{sinks} = {};

	bless $me, $class;

	$me
}

sub add {
	my $me = shift;
	my $sink = shift;

	my $h = $sink->{src};

	$me->{sinks}{$h} = $sink;
	$me->{select}->add($h);
}

sub run {
	my $me = shift;

	while(my @handles = $me->{select}->can_read()) {
		foreach my $h (@handles) {
			if(defined(my $sink = $me->{sinks}{$h})) {
				$sink->read($me);
			}
		}
	}
}






package Sink;

use IPC::Open3;
use Data::Dumper;

sub new {
	my $class = shift;
	my $name = shift;
	my $src = shift;

	# if stdin, we want to buffer lines and execute actions based on these
	# if pipe, we shovel through to output directly, unbuffered
	# if pty, we shovel through in two directions: a duplex pipe

	my $me = {
		name => $name,
		src => $src,
		buffer => ''
	};

	bless $me, $class;

	$me
}

sub read {
	my $me = shift;
	my $runner = shift;

	if(defined(my $c = sysread($me->{src}, $me->{buffer}, 4096, length($me->{buffer})))) {
		$me->onBuffer($runner);
		$c
	}
	else {
		die "Problem reading $me->{name}: $!";
	}
}

sub onBuffer {
}

sub close {
	my $me = shift;
	close($me->{src}) or die "Can't close...";
}

sub lg {
	my $s = shift;
	print STDERR "$s\n";
}


package LineSink;

use base 'Sink';

sub new {
	my $class = shift;

	my $me = $class->SUPER::new(@_);
	bless $me, $class; 

	$me->{lines} = [];

	$me
}

sub onBuffer {
	my $me = shift;
	my $runner = shift;

	while($me->{buffer} =~ /^(?<line>[^\n]*)\n(?<rest>[\s\S]*)$/m) {
		push(@{$me->{lines}}, $+{line});
		$me->{buffer} = $+{rest};
	}

	if(scalar @{$me->{lines}}) {
		$me->onLine($runner);
	}
}

sub onLine {}







package CorkableStream;

use base 'Sink';

sub new {
	my $class = shift;
	my $name = shift;
	my $src = shift;
	my $dest = shift;

	my $me = $class->SUPER::new($name, $src);
	bless $me, $class;

	$me->{corked} = 1;
	$me->{dest} = $dest;

	$me
}

sub onBuffer {
	my $me = shift;
	my $runner = shift;
	$me->shovel();
}

sub cork {
	my $me = shift;
	$me->{corked} = 1;
}

sub uncork {
	my $me = shift;
	$me->{corked} = 0;
	$me->shovel();
}

sub shovel {
	my $me = shift;
	
	if(!$me->{corked}) {
		while(length($me->{buffer}) > 0) {
			my $c = syswrite($me->{dest}, $me->{buffer});
			$me->{buffer} = substr($me->{buffer}, $c);
		}
	}
}



# instead of asking for a sink or a duplex, with each being given its own pane (imagine!)
# we want access to left or right...
# well, actually, as a first step, each request could just be given a pane
#
# which means we need a tmux session attached up top (ie here)
#
#



package Controller;

use base 'LineSink';
use POSIX qw(mkfifo remove);

sub new {
	my $class = shift;

	my $me = $class->SUPER::new(@_);
	bless $me, $class;

	$me
}

sub onLine {
	my $me = shift;
	my $runner = shift;

	while(defined(my $line = shift(@{$me->{lines}}))) {
		given($line) {
			when(/^pty ([\w\/]+)/) {
				my $root0 = getFifo();
				my $root1 = getFifo();
				my $root2 = getFifo();

				my $pid = fork;
				if($pid == 0) {
					# exec "$ENV{VARS_PATH}/ptyize -0$tty -1$tty cat"
					# exec "socat -r/tmp/socat.log file:$tty,rawer exec:'$ENV{VARS_PATH}/ptyize ',pty,ctty";
					# exec "socat -r/tmp/socat.log file:$tty,cfmakeraw exec:'strace -f -o/tmp/strace.log cat',pty,ctty,cfmakeraw"; #  tmux -Lvars new-session $ENV{VARS_PATH}/termProxy.sh $root0 $root1 $root2',pty,ctty";
					exec "socat -r/tmp/socat.log file:$tty,cfmakeraw exec:'tmux -Lvars new-session strace -f -o/tmp/strace.log $ENV{VARS_PATH}/termProxy.sh $root0 $root1 $root2',pty,icanon=1";
				}
				else {
					$me->{pid} = $pid;
					$me->{pty} = $pid;
					$me->{root0} = $root0;
					$me->{root1} = $root1;
					$me->{root2} = $root2;
				}
			}
			when("sink") {
				say "sink $me->{root2}";
			}
			when('duplex') {
				say "duplex $me->{root0} $me->{root2}";
				# (my $send, my $return) = $me->getDuplex($runner);
				# say "duplex $send $return";
			}

			# todo and close?????
		}
	}
}

sub getFifo {
	my $fifoPath = fifoPath();
	mkfifo($fifoPath, 0700) or die "BAD";
	$fifoPath
}

sub getSink {
	my $me = shift;
	my $runner = shift;
	my $name = shift;
	my $dest = shift;

	my $fifoPath = fifoPath();

	mkfifo($fifoPath, 0700) or die "BAD";
	open(my $fifo, "+< $fifoPath") or die "BAD $fifoPath $!";

	my $stream = new CorkableStream("controller:$name", $fifo, $dest);
	$stream->uncork(); #!!!!!!
	$runner->add($stream);

	$fifoPath
}

sub getDuplex {
	my $me = shift;
	my $runner = shift;

	my $returnPath = fifoPath();
	mkfifo($returnPath, 0700) or die "BAD";
	open(my $return, "+< $returnPath") or die "BAD";
	$return->autoflush(1);

	my $sendPath = fifoPath();
	mkfifo($sendPath, 0700) or die "BAD";
	open(my $send, "+> $sendPath") or die "BAD";

	open(my $tty1, "> $tty") or die "BAD";
	my $stream0 = new CorkableStream('controller>tty', $return, $tty1);
	$stream0->uncork(); #!!!!!!
	$runner->add($stream0);

	open(my $tty0, "< $tty") or die "BAD";
	my $stream1 = new CorkableStream('controller<tty', $tty0, $send);
	$stream1->uncork(); #!!!!!!
	$runner->add($stream1);

	($sendPath, $returnPath)
}

# todo clear up old streams

# todo clean up fifos

sub fifoPath {
	'/tmp/vars-io-' . uuid()
}

sub uuid {
	open my $fh, "/proc/sys/kernel/random/uuid" or die $!;
	chomp(my $id = scalar <$fh>);
	$id
}
