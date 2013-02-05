package Mojocoin::Faucet::Controller;

use Mojo::Base 'Mojolicious::Controller';

use Mojocoin::Faucet::Util qw( :all );

use AnyEventX::CondVar;
use AnyEventX::CondVar::Util qw( :all );
use GD::Barcode::QRcode;
use URI::Escape;

use Scalar::Util qw( looks_like_number );

use List::Util qw( min );

sub home {
    my $self = shift;

    $self->render_later;

    $self->bitcoin->GetBalance
        ->cons( $self->bitcoin->GetAccountAddress( '' ) )
        ->cons( $self->ip_authorized )
        ->then( sub {
            my ( $balance, $address, $authorized ) = @_;

            defined $balance && defined $address
                or $self->flash(
                    error => "Could not communicate with the "
                        . "local bitcoin node" 
                );

            $self->render(
                template => '/controller/home',
                address => $address || 'No Address',
                balance => format_balance( $balance ),
                max_withdrawal => max_withdrawal( $balance ),
                url => $address ?
                    uri_escape( "bitcoin:$address" ) : '',
                authorized => $authorized,
            );
        });
}

# Automatically render template controller/about.html.ep
sub about { }

sub request {
    my $self = shift;

    $self->render_later;

    my ( $address, $amount ) =
        ( $self->param( 'address' ), $self->param( 'amount' ) );

    # Trim whitespaces from user input
    $address =~ s/^\s+|\s+$//g;
    $amount =~ s/^\s+|\s+$//g;

    # Validate address integrity before sending
    # it to bitcoind for validation
    $address =~ m/^\w+$/ or do {
        $self->flash( error => 'Invalid bitcoin address' );
        $self->redirect_to( '/' );
        return;
    };

    # Validate the amount as a numeric value
    looks_like_number( $amount ) 
        && $amount >= 0.00000001 or do {
        $self->flash( error => "Invalid bitcoin amount" );
        $self->redirect_to( '/' );
        return;
    };

    # Round up to the next Satoshi 
    $amount = sprintf( '%.8f', $self->param( 'amount' ) || 0 );

    # Explicit conversion to numeric. Otherwise SendFrom doesn't work
    $amount += 0.00;

    $self->ip_authorized
        ->cons( $self->bitcoin->GetBalance )
        ->cons( $self->bitcoin->ValidateAddress( $address ) )
        ->then( sub {
            my ( $authorized, $balance, $valid ) = @_;

            if( not $authorized ){
                $self->redirect_to( '/' );
                return;
            }

            defined $balance && defined $valid or do {
                $self->flash( error => "Could not communicate "
                    . "with the local bitcoin node" );
                $self->redirect_to( '/' );
                return;
            };

            if( not $valid->{ isvalid } ){
                $self->flash( error => 'Invalid bitcoin address' );
                $self->redirect_to( '/' );
                return;
            }

            my $max_withdrawal = max_withdrawal( $balance );

            $amount <= $max_withdrawal or do {
                $self->flash( error => "We currently only accept "
                    . "withdrawals up to $max_withdrawal Bitcoins" );
                $self->redirect_to( '/' );
                return;
            };

            $self->bitcoin->SendFrom( '' => $address => $amount )
                ->cons( $self->ip_increment )
                ->then( sub {
                    $self->flash( message => 
                        "$amount BTC sent to $address" );
                    # Remove the POST request from the browser cache
                    $self->redirect_to( '/' );
                });
        });
}

sub qrcode {
    my $self = shift;
    $self->render( 
        data => GD::Barcode::QRcode->new(
            $self->param( 'string' ), {
                Version => 4,
                ModuleSize => 5,
            })->plot->png, 
        format => 'png' 
    );
}

1;
