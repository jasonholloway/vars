#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use IO::Select;
use 5.034;
no warnings 'experimental';

use lib $ENV{VARS_PATH};

my $pts = shift;

$|++;

sub main {
	while (my $line = hear()) {
		given($line) {
			when("getPipe") {
				say "pipe /proc/$$/fd/2";
			}
			when('getPty') {
				# say "pty $pts /proc/$$/fd/2";
				say "pty /dev/tty";  #/proc/$$/fd/2";
			}
		}
	}
}

sub getPipe {
	# new up a fifo
	# and return the path to it
}

sub getPty {
	# new up two fifos
	# and return both paths
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
