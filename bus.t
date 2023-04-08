use strict;
use warnings;

use lib '.';
use Test2::V0;

BusTest->run(
	['p1', 'p2'],
	sub {
		my ($root, $p1, $p2) = @_;

		$root->say('@ASK p1');
		$root->say('hello');
		$root->say('@YIELD');
		$root->say('@PUMP');
		$root->say('@PUMP');
		is($p1->hear(), 'hello');

		$p1->say('woof');
		$p1->say('@YIELD');
		is($root->hear(), 'woof');

		$root->say('@END');



		# my $answer1 = $root->hear();
		# is($answer1, 'woofwoofwoof?');

		# $root->say('yapyapyap');
		# $root->say('@YIELD');

		# my $answer2 = $root->hear();
		# is($answer2, 'yapyapyap???');

		# $root->say('@END');
	});

done_testing;





package BusTest;

sub run {
	shift;
	my $spec = shift;
	my $sub = shift;

	$_ = Fixture->new($spec);

	$sub->(@{$_->{peers}});

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

	$ENV{VARS_DEBUG}='1';

	$me->{bus} = {
		pid => open3(my $rootSend,
								 my $rootReturn,
								 '>&STDERR',
								 "stdbuf -oL " . $ENV{VARS_PATH} . "/bus.awk -v PROCS='" . join(';', @procs) . "'"
								)
	};

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

sub new {
	my $class = shift;
	my $name = shift;
	my $send = shift;
	my $return = shift;

	my $me = {};
	bless $me, $class;

	$me->{send} = $send;
	$me->{return} = $return;

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
