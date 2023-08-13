use strict;
use warnings;
use 5.034;
no warnings 'experimental';

use lib '.';
use Test2::V0;
use POSIX ":sys_wait_h";

sub lg {
  my $s = shift;
  print STDERR "$s\n";
}

BusTest->run(
	['a', 'b'],
	sub {
		my ($root, $a, $b) = @_;

		$root->say('@ASK a');
		$root->say('hello');
		is($a->hear(), 'hello');

		$a->say('woof');
		is($root->hear(), 'woof');

		$a->say('@END');
		$root->say('@END');

		$root->say('@ASK b');
		$root->say('meeow');
		is($b->hear(), 'meeow');

		$b->say('@ASK a');
		$b->say('moo');
		is($a->hear(), 'moo');

		$a->say('woof');
		is($b->hear(), 'woof');

		$b->say('@END');
		$b->say('oink oink');
		is($root->hear(), 'oink oink');

		$root->say('baa');

		is($b->hear(), 'baa');
	});

BusTest->run(
	['p1', 'p2'],
	sub {
		my ($root, $p1, $p2) = @_;

		# todo cover nothing being said before yield
		$root->say('@ASK p1');
		$root->say('hi from root 0');

		$p1->say('@ASK p2');
		$p1->say('hello, p2');

		$root->say('hi from root 1');
		$p2->say('from p2');
		$root->say('hi from root 2');

		is($p1->hear(), 'hi from root 0');
		is($p1->hear(), 'hi from root 1');
		is($p1->hear(), 'hi from root 2');
		is($p1->hear(), 'from p2');

		$p1->say('@ASK p2');
		$p2->say('blah');
		is($p1->hear(), 'blah');
	});

BusTest->run(
	['p1'],
	sub {
		my ($root, $p1) = @_;

		$root->say('@ASK p1');
		$root->say('hello');
		sleep(1);
		is($p1->canHear(), 1);
		is($root->canHear(), 0);

		$p1->say('yo');
		sleep(1);
		is($root->canHear(), 1);

		is($p1->hear(), 'hello');
		is($p1->canHear(), 0);
	});


# # only relay freely up to first command
BusTest->run(
	['p1', 'p2'],
	sub {
		my ($root, $p1, $p2) = @_;

		$root->say('@ASK p1');
		$root->say('hello');
		is($p1->hear(), 'hello');

		$p1->say('woof');
		is($root->hear(), 'woof');

		$p1->say('@ASK p2');
		$p1->say('oink');
		sleep(1);
		is($root->canHear(), 0);
		is($p2->canHear(), 1);
		is($p2->hear(), 'oink');
	});


# # bus should close when stdin closed
BusTest->run(
	['p1'],
	sub {
		my ($root, $p1, $fx) = @_;

		$root->say('@ASK p1');
		$root->say('hello');
		$p1->say('woof');

		close($fx->{rootSend});

		sleep 1;

		isnt(waitpid($fx->{bus}{pid}, WNOHANG), 0, "bus shouldn't still be running");

		#todo check that peer has closed as well
	}, { debug => 1 });



done_testing;





package BusTest;

sub run {
	shift;
	my $spec = shift;
	my $sub = shift;
	my $flags = shift;

	$_ = Fixture->new($spec, $flags);

	$sub->(@{$_->{peers}}, $_);

	$_->cleanup();
}


package Fixture;

use IPC::Open3;
use File::Temp qw(tempdir);
use File::Spec::Functions qw(catfile);
use POSIX qw(mkfifo);
use Fcntl;
use Data::Dumper;
use strict;
use warnings;

sub new {
	my $class = shift;
	my $peers = shift;
	my $flags = shift || {};

	my $me = {};
	bless $me, $class;

	$me->{dir} = tempdir(CLEANUP=>1);

	my @procs;

	for my $pn (@{$peers}) {
		my $sendPath = catfile($me->{dir}, "${pn}-send");
		my $returnPath = catfile($me->{dir}, "${pn}-return");
		my $scriptPath = catfile($me->{dir}, "${pn}.sh");

		mkfifo($sendPath, 0700) or die "BAD";
		mkfifo($returnPath, 0700) or die "BAD";

		open(my $script, ">$scriptPath") or die "BAD";
		print $script <<"END_SCRIPT";
#!/bin/bash
cat $sendPath &
cat >$returnPath
wait
END_SCRIPT
		close($script);

		chmod(0755, $scriptPath);

		open(my $send, "+> $sendPath") or die "BAD";
		open(my $return, "+< $returnPath") or die "BAD";

		push(@{$me->{peers}}, Peer->new($pn, $send, $return));
		push(@procs, "$pn:$scriptPath");
	}

	$ENV{VARS_DEBUG}=$flags->{debug};

	my $cmd = $ENV{VARS_PATH} . "/bus.pl '" . join(';', @procs) . "'";

	$me->{bus} = {
		pid => open3(my $rootSend, my $rootReturn, '>&STDERR', $cmd)
	};

	$me->{rootSend} = $rootSend;

	unshift(@{$me->{peers}}, Peer->new('root', $rootSend, $rootReturn));

	$me
}

sub cleanup {
	my $me = shift;

	for my $peer (@{$me->{peers}}) {
		close($peer->{send});
		close($peer->{return});
	}

	kill('SIGTERM', $me->{bus}{pid});
	waitpid($me->{bus}{pid}, 0);
}


package Peer;

use IO::Handle;
use IO::Poll qw(POLLIN);

sub new {
	my $class = shift;
	my $name = shift;
	my $send = shift;
	my $return = shift;

	my $me = {};
	bless $me, $class;

	$me->{send} = $send;
	$me->{return} = $return;

	my $poll = IO::Poll->new();
	$poll->mask($return, POLLIN);
	$me->{poll} = $poll;

	$me
}

sub say {
	my $me = shift;
	my $line = shift;

	my $h = $me->{send};
	print $h $line . "\n";
	$h->flush();
}

sub hear {
  my $me = shift;
	my $h = $me->{return};

	while(1) {
		if(defined(my $line = <$h>)) {
		  chomp($line);

			if($line eq '@PUMP') {
				$me->say('@PUMP');
			}
			else {
				return $line;
			}
		}
		else {
			die "nothing to read";
		}
	}
}

sub canHear {
	my $me = shift;
	my $poll = $me->{poll};
	$poll->poll(0);
}
