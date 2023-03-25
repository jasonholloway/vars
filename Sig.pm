use strict;
use warnings;

package Sig;

sub parseInps {
	my $raw = shift;
	my @ac;

	while($raw =~ /((?<alias>\w+):)?(?<name>\w+)(?<postfix>[\*]?)({(?<pins>[^}]*)})?/g) {
		my %inp;

		$inp{name} = $+{name};

		if($+{alias}) {
			$inp{alias} = $+{alias};
		}

		unless($+{postfix} eq '*') {
			$inp{single} = 1;
		}

		if(my $pins = $+{pins}) {
			$inp{pins} = {};

			while($pins =~ /(?<name>\w+)=(?<val>\w*)/g) {
				$inp{pins}{$+{name}} = $+{val};
			}
		}

		push(@ac, \%inp);
	}

	\@ac;
}

1;
