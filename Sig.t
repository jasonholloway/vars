use strict;
use warnings;

use lib '.';

use Test2::V0;
use Sig;

is(
	Sig::tokenize("woof: woof"),
	[
		[Sig::WORD, 'woof'],
		[Sig::COLON, ':'],
		[Sig::SPACE, ' '],
		[Sig::WORD, 'woof'],
	]
 );

is(
	Sig::tokenize("bob:bear   {name=bob|robert} dave:dog+wolf"),
	[
		[Sig::WORD, 'bob'],
		[Sig::COLON, ':'],
		[Sig::WORD, 'bear'],
		[Sig::SPACE, '   '],
		[Sig::BRACE_OPEN, '{'],
		[Sig::WORD, 'name'],
		[Sig::EQUALS, '='],
		[Sig::WORD, 'bob'],
		[Sig::OR, '|'],
		[Sig::WORD, 'robert'],
		[Sig::BRACE_CLOSE, '}'],
		[Sig::SPACE, ' '],
		[Sig::WORD, 'dave'],
		[Sig::COLON, ':'],
		[Sig::WORD, 'dog'],
		[Sig::PLUS, '+'],
		[Sig::WORD, 'wolf'],
	]
 );

is(
	Sig::parse("dog"),
	[
		{
			alias => "dog",
			from => [{ name => "dog" }]
		}
	]
 );

is(
	Sig::parse("boris:dog"),
	[
		{
			alias => "boris",
			from => [{ name => "dog" }]
		}
	]
 );

is(
	Sig::parse("boris*:dog"),
	[
		{
			alias => "boris",
			from => [{ name => "dog" }],
			modifier => '*'
		}
	]
 );

is(
	Sig::parse("boris:dog{breed=Alsatian}"),
	[
		{
			alias => "boris",
			from => [{
				name => "dog",
				pins => {
					breed => ["Alsatian"]
				}
			}]
		}
	]
 );

is(
	Sig::parse("boris!:dog{breed=Alsatian}"),
	[
		{
			alias => "boris",
			from => [{
				name => "dog",
				pins => {
					breed => ["Alsatian"]
				}
			}],
			modifier => '!'
		}
	]
 );

is(
	Sig::parse("boris:dog{breed=Alsatian&temperament=loyal}"),
	[
		{
			alias => "boris",
			from => [{
				name => "dog",
				pins => {
					breed => ["Alsatian"],
					temperament => ["loyal"]
				}
			}]
		}
	]
 );

is(
	Sig::parse("colette:dog{breed=Collie|Chihuahua}"),
	[
		{
			alias => "colette",
			from => [
				{
					name => "dog",
					pins => {
						breed => ["Collie", "Chihuahua"]
					}
				}
			]
		}
	]
 );

is(
	Sig::parse("bazza:donkey+pony"),
	[
		{
			alias => "bazza",
			from => [
				{
					name => "donkey",
				},
				{
					name => "pony"
				}
			]
		}
	]
 );

is(
	Sig::parse("bazza:donkey+pony{hair=long}+tapir"),
	[
		{
			alias => "bazza",
			from => [
				{
					name => "donkey",
				},
				{
					name => "pony",
					pins => {
						hair => ["long"]
					}
				},
				{
					name => "tapir"
				}
			]
		}
	]
 );

is(
	Sig::parse("donkey{outlook=grumpy}"),
	[
		{
			alias => "donkey",
			from => [
				{
					name => "donkey",
					pins => {
						outlook => ["grumpy"]
					}
				}
			]
		}
	]
 );

is(
	Sig::parse("morris:monkey{temperament=cheeky|naughty}+baboon doris:donkey"),
	[
		{
			alias => "morris",
			from => [
				{
					name => "monkey",
					pins => {
						temperament => ["cheeky","naughty"]
					}
				},
				{
					name => "baboon",
				}
			]
		},
		{
			alias => "doris",
			from => [
				{
					name => "donkey"
				}
			]
		}
	]
 );

is(
	Sig::parse("bert!:dog{breed=Pomeranian&fur=fluffy} cat*{breed=Tabby} hamster! pet*:bunny+gerbil"),
	[
		{
			alias => "bert",
			from => [{
				name => "dog",
				pins => {
					breed => ["Pomeranian"],
					fur => ["fluffy"]
				}
			}],
			modifier => '!'
		},
		{
			alias => "cat",
			from => [{
				name => "cat",
				pins => {
					breed => ["Tabby"]
				},
				modifier => '*'
			}],
			modifier => '*'
		},
		{
			alias => "hamster",
			from => [{
				name => "hamster",
				modifier => '!'
			}],
			modifier => '!'
		},
		{
			alias => "pet",
			from => [
				{ name => "bunny" },
				{ name => "gerbil" },
			],
			modifier => '*'
		}
	]
);

is(
	Sig::parse("Hairy_dog5{BREED123=Doberman7&Num_Legs=13}"),
	[
		{
			alias => "Hairy_dog5",
			from => [{
				name => "Hairy_dog5",
				pins => {
					BREED123 => ["Doberman7"],
					Num_Legs => [5 + 5 + 3]
				}
			}]
		}
	],
	"parse multifarious names"
);


done_testing;
