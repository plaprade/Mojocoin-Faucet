package Mojocoin::Faucet::Controller;

use Mojo::Base 'Mojolicious::Controller';

use AnyEventX::CondVar;
use AnyEventX::CondVar::Util qw( :all );
use GD::Barcode::QRcode;
use URI::Escape;

sub home {
    my $self = shift;

    $self->render_later;

    # Get a latest address for the default account
    $self->bitcoin->GetBalance
        ->cons( $self->bitcoin->GetAccountAddress( '' ) )
        ->then( sub {
            my ( $balance, $address ) = @_;
            $self->render(
                template => '/controller/home',
                address => $address,
                balance => $balance,
                url => uri_escape( "bitcoin:$address" ),
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

    $self->bitcoin->SendFrom( '' => $address => 0.01 )
        ->then( sub {
            $self->flash( message => "0.01 BTC sent to $address" );
            # Remove the POST request from the browser cache
            $self->redirect_to( '/' );
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
