use strict;
use warnings;

package Sig;
use Data::Dumper;

use constant SPACE => 0;
use constant WORD => 1;
use constant BRACE_OPEN => 2;
use constant BRACE_CLOSE => 3;
use constant COLON => 4;
use constant EQUALS => 5;
use constant OR => 6;
use constant PLUS => 7;
use constant AND => 8;
use constant MODIFIER => 9;

sub parseInps {
	my $raw = shift;
	my @ac;

	while($raw =~ /((?<alias>\w+):)?(?<name>\w+)(?<postfix>[\*]?)({(?<pins>[^}]*)})?/g) {
		my %inp;

		$inp{name} = $+{name};
		$inp{alias} = $+{alias} // $+{name};

		unless($+{postfix} eq '*') {
			$inp{single} = 1;
		}

		if(my $pins = $+{pins}) {
			$inp{pins} = {};

			while($pins =~ /(?<name>\w+)=(?<val>\w*)/g) {
				$inp{pins}{$+{name}} = [$+{val}];
			}
		}

		push(@ac, \%inp);
	}

	\@ac;
}


sub parse {
	$_ = tokenize(shift);
	parseAll();

	sub parseAll {
		my @ac;
		my $i = 0;;

		while($i++ < 20
					and (take(SPACE) or 1)
					and my %inp = parseInp()) {
			push(@ac, \%inp);
		}

		# print STDERR Dumper(\@ac);

		\@ac
	}

	sub parseInp {
		my %ac;

		if(my ($alias, $mod) = take(WORD, MODIFIER, COLON)) {
			$ac{alias} = $alias;
			$ac{from} = [parseSources()];
			$ac{modifier} = $mod;
		}
		elsif(my ($alias) = take(WORD, COLON)) {
			$ac{alias} = $alias;
			$ac{from} = [parseSources()];
		}
		elsif(my %source = parseSource()) {
			$ac{alias} = $source{name};
			$ac{from} = [\%source];
			$ac{modifier} = $source{modifier} if $source{modifier};
		}

		%ac
	}

	sub parseSources {
		if(my %source0 = parseSource()) {
			my @ac = (\%source0);

			while(take(PLUS) and my %source = parseSource()) {
				push(@ac, \%source);
			}

			@ac
		}
		else {
			[]
		}
	}

	sub parseSource {
		if(my ($name) = take(WORD)) {
			my %ac = (
				name => $name
			);

			if(my ($mod) = take(MODIFIER)) {
				$ac{modifier} = $mod;
			}

			if(my %pins = parsePins()) {
				$ac{pins} = \%pins;
			}

			%ac
		}
		else {
			()
		}
	}

	sub parsePins {
		if(take(BRACE_OPEN)) {
			my %ac;

			if(my ($name0,$pin0) = parsePin()) {
				$ac{$name0} = $pin0;

				while(take(AND) and my ($name,$pin) = parsePin()) {
					$ac{$name} = $pin;
				}
			}

			take(BRACE_CLOSE) or die "Missing closing brace after pins!";

			%ac;
		}
		else {
			()
		}
	}

	sub parsePin {
		if(my ($name,undef,$val0) = take(WORD,EQUALS,WORD)) {
			my @ac = ($val0);

			while(my (undef,$v) = take(OR,WORD)) {
				push(@ac, $v);
			}
			
			($name, \@ac)
		}
		else {
			()
		}
	}

	sub skip {
		my $c = shift;
		for(my $i = 0; $i < $c; $i++) {
			shift(@{$_});
		}
	}

	sub peek {
		my @ac;
		my $x = 0;

		foreach my $expected (@_) {
			my $next;
			if($next = $_->[$x] and $next->[0] == $expected) {
				push(@ac, $next->[1]);
				$x++;
			}
			else {
				return ();
			}
		}

		return @ac;
	}

	sub take {
		if(my @found = peek(@_)) {
			skip(scalar @found);
			@found
		}
		else {
			()
		}
	}

	sub atEnd {
		scalar @{$_} == 0
	}
}



sub tokenize {
	my @ac;
	$_ = shift;

	while(my $token = readToken()) {
		push(@ac, $token);
	}

	\@ac;

	sub readToken {
			 (/^( +)/ and emit(SPACE, $1))
		or (/^(\w[\w_0-9]*)/ and emit(WORD, $1))
		or (/^(\{)/ and emit(BRACE_OPEN, $1))
		or (/^(\})/ and emit(BRACE_CLOSE, $1))
		or (/^(:)/ and emit(COLON, $1))
		or (/^(=)/ and emit(EQUALS, $1))
		or (/^(\|)/ and emit(OR, $1))
		or (/^(\+)/ and emit(PLUS, $1))
		or (/^(\&)/ and emit(AND, $1))
		or (/^(\!|\*)/ and emit(MODIFIER, $1))
	}

	sub emit {
		my $t = shift;
		my $s = shift;
		substr($_, 0, length($s), '');
		[$t, $s]
	}
}

1;
