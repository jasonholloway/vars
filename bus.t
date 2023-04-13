use strict;
use warnings;
use 5.034;
no warnings 'experimental';

use lib '.';
use Test2::V0;

BusTest->run(
	['p1', 'p2'],
	sub {
		my ($root, $p1, $p2) = @_;

		$root->say('@ASK p1');
		$root->say('hello');
		$root->say('@YIELD');
		is($p1->hear(), 'hello');

		$p1->say('woof');
		$p1->say('@YIELD');
		is($root->hear(), 'woof');

		$root->say('@END');

		$root->say('@ASK p2');
		$root->say('meeow');
		$root->say('@YIELD');
		is($p2->hear(), 'meeow');

		$p2->say('@ASK p1');
		$p2->say('moo');
		$p2->say('@YIELD');
		is($p1->hear(), 'moo');

		$p1->say('woof');
		$p1->say('@YIELD');
		is($p2->hear(), 'woof');

		$p2->say('@END');
		$p2->say('oink oink');
		is($root->hear(), 'oink oink');

		$p2->say('@YIELD');
		$root->say('baa');
		$root->say('@END');
		is($p2->hear(), 'baa');
	});

# BusTest->run(
# 	[],
# 	sub {
# 		my ($root) = @_;

# 		$root->say('@PAD 8');
# 		$root->say('yo');
# 		is($root->hear(), 'yo');
# 		is($root->hearRaw(), '###');

# 		$root->say('@PAD 12');
# 		$root->say('boo');
# 		is($root->hear(), 'boo');
# 		is($root->hearRaw(), '######');

# 		$root->say('@PAD 0');
# 		$root->say('woo');
# 		$root->say('moo');
# 		is($root->hear(), 'woo');
# 		is($root->hear(), 'moo');

# 	}, { debug=>1 });

# BusTest->run(
# 	['p1', 'p2', 'p3'],
# 	sub {
# 		my ($root, $p1, $p2, $p3) = @_;

# 		$root->say('@ASK p1');
# 		$root->say('hello');
# 		$root->say('@YIELD');
# 		is($p1->hear(), 'hello');

# 		$p1->say('@TAP');
# 		$p1->say('@ASK p2');

# 		$p1->say('squeak');
# 		is($p2->hear(), 'squeak');

# 		$root->say('hoot');
# 		is($p1->hear(), '@TAPPED hoot');
		
# 		# and p2 to say something now

# 	}, 1);

done_testing;





package BusTest;

sub run {
	shift;
	my $spec = shift;
	my $sub = shift;
	my $flags = shift;

	$_ = Fixture->new($spec, $flags);

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
