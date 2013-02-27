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
    min( ceil( $int/1e8 )*1e8 / 100, 5000000000 );
}

sub format_balance {
    my $int = shift || 0;
    sprintf( '%.2f', AmountToJSON( $int ) );
}

1;
