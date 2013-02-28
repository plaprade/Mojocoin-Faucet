package Mojocoin::Faucet::Util;

use strict;
use warnings;

use List::Util qw( min );
use Continuum::BitcoinRPC::Util qw( AmountToJSON JSONToAmount );

use POSIX qw( ceil );

use base 'Exporter';

our @EXPORT_OK = (qw(
    max_withdrawal
    format_balance
));

our %EXPORT_TAGS = (
    all => [ @EXPORT_OK ],
);

sub max_withdrawal {
    my $int = shift || 0;
    my $percent = shift || 1;
    my $max = shift || 21_000_000;
    my $max_satoshi = sprintf( '%.0f', $max * 1e8 );
    min( int( $int * $percent / 100 ), $max_satoshi );
}

sub format_balance {
    my $int = shift || 0;

    my $satoshi = $int % 1e6;
    my $main = ( $int - $satoshi ) / 1e8;
    $satoshi /= 10 while $satoshi % 10 == 0 && $satoshi;

    if ( $satoshi ) {
        "$main<span class='satoshi'>$satoshi</span>";
    } else {
        $main;
    }
}

1;
