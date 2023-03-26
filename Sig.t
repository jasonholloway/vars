use strict;
use warnings;

use lib '.';

use Test2::V0;
use Sig;

is(
	Sig::parseInps("woof"),
	[
		{
			alias => "woof",
			single => 1,
			sources => [{
				name => "woof"
			}]
		},
	],
	"parse single var"
);

is(
	Sig::parseInps("woof*"),
	[
		{
			alias => "woof",
			sources => [{
				name => "woof"
			}]
		}
	],
	"parse single multi var"
);

is(
	Sig::parseInps("dog{breed=Pomeranian}"),
	[
		{
			alias => "dog",
			single => 1,
			sources => [{
				name => "dog",
				pins => {
					breed => ["Pomeranian"]
				}
			}]
		},
	],
	"parse var with scoped pins"
);

is(
	Sig::parseInps("dog{breed=Pomeranian,fur=fluffy}"),
	[
		{
			alias => "dog",
			single => 1,
			sources => [{
					name => "dog",
					pins => {
						breed => [ "Pomeranian" ],
						fur => [ "fluffy" ]
					}
			}]
		},
	],
	"parse var with multiple scoped pins"
);

is(
	Sig::parseInps("dog{breed=Pomeranian,fur=fluffy},cat*{breed=Tabby},hamster"),
	[
		{
			alias => "dog",
			single => 1,
			sources => [{
				name => "dog",
				pins => {
					breed => "Pomeranian",
					fur => "fluffy"
				}
			}]
		},
		{
			alias => "cat",
			sources => [{
				name => "cat",
				pins => {
					breed => "Tabby"
				}
			}]
		},
		{
			alias => "hamster",
			single => 1
		}
	],
	"parse multiple vars with scoped pins"
);

is(
	Sig::parseInps("Hairy_dog5*{BREED123=Doberman7,Num_Legs=13}"),
	[
		{
			alias => "Hairy_dog5",
			sources => {
				name => "Hairy_dog5",
				pins => {
					BREED123 => "Doberman7",
					Num_Legs => 13
				}
			}
		}
	],
	"parse multifarious names"
);

is(
	Sig::parseInps("teddy:dog{breed=Pomeranian} boris:dog{breed=Alsation}"),
	[
		{
			alias => "teddy",
			single => 1,
			sources => [{
				name => "dog",
				pins => {
					breed => ["Pomeranian"]
				}
			}]
		},
		{
			alias => "boris",
			single => 1,
			sources => [{
				name => "dog",
				pins => {
					breed => ["Alsation"]
				}
			}]
		},
	],
	"parse aliased vars"
);

is(
	Sig::parseInps("dog:poodle+doberman+terrier"),
	[
		{
			alias => "dog",
			sources => [
				{
					name => "poodle"
				},
				{
					name => "doberman"
				},
				{
					name => "terrier"
				}
			]
		}
	],
	"parses var sums"
);

# is(
# 	Sig::parseInps("dog*{breed=Poodle|Doberman}"),
# 	[
# 		{
# 			name => "dog",
# 			pins => {
# 				breed => ["Poodle", "Doberman"]
# 			}
# 		}
# 	],
# 	"parses pin sums"
# );


done_testing;
