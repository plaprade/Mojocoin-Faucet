#!/usr/bin/env perl
use strict;
use warnings;

use Pod::Markdown;

my $parser = Pod::Markdown->new;

open( IN, '<lib/Mojocoin/Faucet.pm' );
open( OUT, '>README.md' );

$parser->parse_from_filehandle( \*IN );
my $text = $parser->as_markdown;

my ( $l, $e ) = ( '\n[ ]{4}[^\n]*', '\n[ ]*' );
$text =~ s/($l(($l|$e)*$l)?\n)/\n```perl$1```\n/gs;

print OUT $text;

close( OUT );
close( IN );
