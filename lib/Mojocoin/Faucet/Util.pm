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
    my $reserve = shift || 5000;
    my $positive_reserve = $int - $reserve < 0 ? 0 : $int - $reserve;
    min( int( $int * $percent / 100 ), $max, $positive_reserve );
}

sub format_balance {
    my $int = shift || 0;

    my $satoshi = $int % 1e6;
    my $main = do {
        my $n = $int - $satoshi;
        if ( $satoshi or $n % 1e8 )  {
            sprintf '%0.02f', $n * 1e-8;
        } else {
            sprintf '%d', $n * 1e-8;
        }
    };

    if ( $satoshi ) {
        my $fsatoshi = do {
            if ( $satoshi % 1e2 ) {
                sprintf '%06d', $satoshi;
            } elsif ( $satoshi % 1e4 ) {
                sprintf '%04d', ( $satoshi / 1e2 );
            } else {
                sprintf '%02d', ( $satoshi / 1e4 );
            }
        };
        "$main<span class='satoshi'>$fsatoshi</span>";
    } else {
        $main;
    }
}

1;
