use strict;
use warnings;

use lib '.';

use Test2::V0;
use Sig;

is(
	Sig::parseInps("woof"),
	[
		{
			name => "woof",
			single => 1,
		},
	],
	"parse single var"
);

is(
	Sig::parseInps("woof*"),
	[
		{
			name => "woof",
		},
	],
	"parse single multi var"
);

is(
	Sig::parseInps("dog{breed=Pomeranian}"),
	[
		{
			name => "dog",
			single => 1,
			pins => {
				breed => "Pomeranian"
			}
		},
	],
	"parse var with scoped pins"
);

is(
	Sig::parseInps("dog{breed=Pomeranian,fur=fluffy}"),
	[
		{
			name => "dog",
			single => 1,
			pins => {
				breed => "Pomeranian",
				fur => "fluffy"
			}
		},
	],
	"parse var with multiple scoped pins"
);

is(
	Sig::parseInps("dog{breed=Pomeranian,fur=fluffy},cat*{breed=Tabby},hamster"),
	[
		{
			name => "dog",
			single => 1,
			pins => {
				breed => "Pomeranian",
				fur => "fluffy"
			}
		},
		{
			name => "cat",
			pins => {
				breed => "Tabby"
			}
		},
		{
			name => "hamster",
			single => 1,
		}
	],
	"parse multiple vars with scoped pins"
);

is(
	Sig::parseInps("Hairy_dog5*{BREED123=Doberman7,Num_Legs=13}"),
	[
		{
			name => "Hairy_dog5",
			pins => {
				BREED123 => "Doberman7",
				Num_Legs => "13"
			}
		},
	],
	"parse multifarious names"
);

is(
	Sig::parseInps("teddy:dog{breed=Pomeranian} boris:dog{breed=Alsation}"),
	[
		{
			name => "dog",
			alias => "teddy",
			single => 1,
			pins => {
				breed => "Pomeranian"
			}
		},
		{
			name => "dog",
			alias => "boris",
			single => 1,
			pins => {
				breed => "Alsation"
			}
		},
	],
	"parse aliased vars"
);


done_testing;
