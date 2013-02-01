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

    # Get a latest address for the default account
    $self->bitcoin->GetBalance
        ->cons( $self->bitcoin->GetAccountAddress( '' ) )
        ->cons( $self->ip_authorized )
        ->then( sub {
            my ( $balance, $address, $authorized ) = @_;
            $self->render(
                template => '/controller/home',
                address => $address,
                balance => $balance,
                url => uri_escape( "bitcoin:$address" ),
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

    my $amount = $self->param( 'amount' ) || 5;

    # TODO: This is CRAP. We need a better check for an address
    # Probably decode_base58check()
    $address =~ m/^\w+$/
        or do {
            $self->flash( error => "Bitcoin address doesn't "
                . "look like a valid address" );
            $self->redirect_to( '/' );
            return;
        };

    looks_like_number( $amount )
        or do {
            $self->flash( error => "Bitcoin amount doesn't "
                . "look like a number" );
            $self->redirect_to( '/' );
            return;
        };

    # Explicit conversion to Numeric value
    $amount = min( $amount, 5.00 ) + 0.00;

    $self->ip_authorized
        ->cons( $self->bitcoin->GetBalance )
        ->then( sub {
            my ( $authorized, $balance ) = @_;

            if( not $authorized ){
                $self->redirect_to( '/' );
                return;
            };

            if( $balance < $amount ){
                $self->flash( error => "Not enough bitcoins "
                    . "in the Faucet to process your withdrawal" );
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
