package Mojocoin::Faucet::Controller;

use Mojo::Base 'Mojolicious::Controller';

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
                balance => $balance || 'No Balance',
                url => $address ?
                    uri_escape( "bitcoin:$address" ) : '',
                ip => $self->tx->remote_address,
                authorized => $authorized,
            );
        });
}

# Automatically render template controller/about.html.ep
sub about { }

sub request {
    my $self = shift;

    $self->render_later;

    ( my $address = $self->param( 'address' ) )
        =~ s/^\s+|\s+$//;

    my $amount = $self->param( 'amount' );

    looks_like_number( $amount ) 
        && $amount >= 0.00000001 or do {
        $self->flash( error => "Invalid bitcoin amount: $amount" );
        $self->redirect_to( '/' );
        return;
    };

    $amount <= 5 or do {
        $self->flash( error => "We only accept withdrawals "
            . "up to 5 Bitcoins" );
        $self->redirect_to( '/' );
        return;
    };

    # Explicit conversion to Numeric value
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
                $self->flash( error => "Invalid bitcoin address: "
                    . $address );
                $self->redirect_to( '/' );
                return;
            }

            if( $balance < $amount ){
                $self->flash( error => "Not enough bitcoins "
                    . "in the faucet to process your withdrawal" );
                $self->redirect_to( '/' );
                return;
            }

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
                Version => 5,
                ModuleSize => 5,
            })->plot->png, 
        format => 'png' 
    );
}

1;
