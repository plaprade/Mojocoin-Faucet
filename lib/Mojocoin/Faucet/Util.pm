package Mojocoin::Faucet::Util;

use List::Util qw( min );

use base 'Exporter';

our @EXPORT_OK = (qw(
    max_withdrawal
    format_balance
));

our %EXPORT_TAGS = (
    all => [ @EXPORT_OK ],
);

sub max_withdrawal {
    my $balance = shift;
    sprintf( '%.2f', 
        defined $balance ? 
            min( $balance/100, 5 ) : 0 );
}

sub format_balance {
    my $balance = shift;
    sprintf( '%.2f', 
        defined $balance ?
            int( $balance*100 )/100 : 0 );
}

1;
