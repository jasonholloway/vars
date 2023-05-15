#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use IO::Select;
use 5.034;
no warnings 'experimental';

use lib $ENV{VARS_PATH};
use IO::Pty;

my $pts = shift;

$|++;

sub main {
  my $controller = new Controller('controller', *STDIN);

  my $select = new IO::Select([ $controller->{from} ]);

  while(my @handles = $select->can_read()) {
		foreach my $h (@handles) {
			if($h eq $controller->{from}) {
				$controller->read();
			}
		}
	}


	# while (my $line = hear()) {
	# 	given($line) {
	# 		when("getPipe") {
	# 			say "pipe /proc/$$/fd/2";
	# 		}
	# 		when('getPty') {
	# 			my $pty = getPty();
	# 			say "pty $pty";
	# 		}

	# 		# todo and close?????
	# 	}
	# }
}

sub getPipe {
	#...
}

sub getPty {
	my $pty = new IO::Pty;
	# print $pty, "WOOFWOOF\n";
	$pty->ttyname();

	# and now we want to read from above
}

sub lg {
	my ($line) = @_;
	print STDERR "$line\n";
}

sub hearWords {
	return split($_[0] // ' ', hear());
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

main();


package Sink;

use IPC::Open3;
use Data::Dumper;

sub new {
  my $class = shift;
  my $name = shift;
	my $from = shift;

	# if stdin, we want to buffer lines and execute actions based on these
	# if pipe, we shovel through to output directly, unbuffered
	# if pty, we shovel through in two directions: a duplex pipe

  my $me = {
    name => $name,
    from => $from,
  };

  bless $me, $class;

  $me
}

sub read {
  my $me = shift;

  if(defined(my $c = sysread($me->{return}, $me->{buffer}, 4096, length($me->{buffer})))) {
		$me->onBuffer();
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
  close($me->{from}) or die "Can't close...";
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
	
	while($me->{buffer} =~ /^(?<line>[^\n]*)\n(?<rest>[\s\S]*)$/m) {
		push(@{$me->{lines}}, $+{line});
		$me->{buffer} = $+{rest};
	}

	if(scalar @{$me->{lines}}) {
		$me->onLine();
	}
}

sub onLine {
}


package Controller;

use base 'LineSink';

sub new {
	my $class = shift;

	my $me = $class->SUPER::new(@_);
	bless $me, $class;

	$me
}

sub onLine {
	my $me = shift;

  while(defined(my $line = shift(@{$me->{lines}}))) {
    Sink::lg("HANDLE [$me->{name}...] $line");
		given($line) {
			when("getPipe") {
				Sink::lg("woof woof woof");
				# say "pipe /proc/$$/fd/2";
			}
			when('getPty') {
				# my $pty = getPty();
				# say "pty $pty";
			}

			# todo and close?????
		}
  }
}
