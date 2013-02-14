#!/usr/bin/env perl
use strict;
use warnings;

use Pod::Markdown;

my $parser = Pod::Markdown->new;

open IN, '<lib/Mojocoin/Faucet.pm';
open OUT, '>README.md';

$parser->parse_from_filehandle( \*IN );
my $text = $parser->as_markdown;

my $codefirst = qr/\s{4}\S.*/;
my $code = qr/\s{4}.*/;
$text =~ s{
    \n
    (?:\s{4}\#\s*lang:\s*(?<lang>\S+)\s*\n)?
    (?<code>
            $codefirst\n
            (?:$code\n|\s*\n)*
            $code\n
        |
            $codefirst\n
    )
}{
    "\n```" . ( $+{lang} || 'perl' ) . "\n$+{code}```\n";
}gsxe;

print OUT $text;

close OUT;
close IN;
