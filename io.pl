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
    die "Problem reading $me->{alias}: $!";
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
			when("sink") {
				my $pipe = $me->getSink($runner);
	 			say "sink $pipe";
			}
			when('duplex') {
				(my $send, my $return) = $me->getDuplex($runner);
				say "duplex $send $return";
			}

			# todo and close?????
		}
  }
}

sub getSink {
	my $me = shift;
	my $runner = shift;

	my $fifoPath = fifoPath();

	mkfifo($fifoPath, 0700) or die "BAD";
	open(my $fifo, "+< $fifoPath") or die "BAD $fifoPath $!";

	my $stream = new CorkableStream('anon', $fifo, *STDERR);
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
	my $stream0 = new CorkableStream('anon', $return, $tty1);
	$stream0->uncork(); #!!!!!!
	$runner->add($stream0);

	open(my $tty0, "< $tty") or die "BAD";
	my $stream1 = new CorkableStream('anon', $tty0, $send);
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
