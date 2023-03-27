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

		while(my $r = parseInp()) {
			push(@ac, $r);
		}

		\@ac
	}

	sub parseInp {
		if(my ($alias) = take(WORD, COLON)) {
			{
				alias => $alias,
				from => parseFrom()
			}
		}
		elsif(my ($name) = take(WORD)) {
			{
				alias => $name,
				from => [{
					name => $name
				}]
			}
		}
	}

	sub parseFrom {
		[]
	}

	sub take {
		my @ac;
		my $x = 0;

		foreach my $expected (@_) {
			my $next;
			if($next = $_->[$x] and $next->[0] == $expected) {
				push(@ac, $next->[1]);
				$x++;
			}
			else {
				return;
			}
		}

		for(my $i = 0; $i < $x; $i++) {
			shift(@{$_});
		}

		return @ac;
	}

	sub step {
		my $c = shift // 1;
		for(my $i = 0; $i < $c; $i++) {
			pop(@{$_});
		}
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
	}

	sub emit {
		my $t = shift;
		my $s = shift;
		substr($_, 0, length($s), '');
		[$t, $s]
	}
}





# sub parse {
# 	my $raw = shift;

# 	my $parseAlias = sub {
# 		if( $raw =~ /(?<alias>\w+):/)
# 	};

	
# }


1;
