package Mojocoin::Faucet::Controller;

use Mojo::Base 'Mojolicious::Controller';

use Mojocoin::Faucet::Util qw( :all );
use Continuum::BitcoinRPC::Util qw( AmountToJSON JSONToAmount );

use Continuum;
use GD::Barcode::QRcode;
use URI::Escape;

use Scalar::Util qw( looks_like_number );

use List::Util qw( min );

sub home {
    my $self = shift;

    $self->render_later;

    my $account = $self->app->config->{bitcoin}->{account};
    my $percent = $self->app->config->{limits}->{max_percent};
    my $max = JSONToAmount( $self->app->config->{limits}->{max_amount} );
    my $reserve = JSONToAmount( $self->app->config->{limits}->{min_reserve} );
    $self->bitcoin->GetBalance( $account )
        ->merge( $self->bitcoin->GetAccountAddress( $account ) )
        ->merge( $self->ip_authorized )
        ->then( sub {
            my ( $balance_float, $address, $authorized ) = @_;

            my $balance = JSONToAmount( $balance_float );

            defined $balance && defined $address
                or $self->flash(
                    error => "Could not communicate with the "
                        . "local bitcoin node" 
                );

            my $max_withdrawal =
                max_withdrawal( $balance, $percent, $max, $reserve );
            $self->render(
                template => '/controller/home',
                address => $address || 'No Address',
                fbalance => format_balance( $balance ),
                max_withdrawal => AmountToJSON( $max_withdrawal ),
                fmax_withdrawal => format_balance( $max_withdrawal ),
                url => $address ?  uri_escape( "bitcoin:$address" ) : q{},
                authorized => $authorized,
            );
        })->persist;
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
    looks_like_number( $amount ) or do {
        $self->flash( error => "Invalid bitcoin amount" );
        $self->redirect_to( '/' );
        return;
    };

    # Round up to the next Satoshi 
    $amount = JSONToAmount( $self->param( 'amount' ) || 0 );

    $amount > 0 or do {
        $self->flash( error => "Invalid bitcoin amount" );
        $self->redirect_to( '/' );
        return;
    };

    # Explicit conversion to numeric. Otherwise SendFrom doesn't work
    $amount += 0;

    my $account = $self->app->config->{bitcoin}->{account};
    my $percent = $self->app->config->{limits}->{max_percent};
    my $max = JSONToAmount( $self->app->config->{limits}->{max_amount} );
    my $reserve = JSONToAmount( $self->app->config->{limits}->{min_reserve} );
    $self->ip_authorized
        ->merge( $self->bitcoin->GetBalance( $account ) )
        ->merge( $self->bitcoin->ValidateAddress( $address ) )
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

            $balance = JSONToAmount( $balance );
            my $max_withdrawal =
                max_withdrawal( $balance, $percent, $max, $reserve );

            # INT comparison here
            $amount <= $max_withdrawal or do {
                $self->flash( error => "We currently only accept "
                    . "withdrawals up to "
                    . AmountToJSON( $max_withdrawal )
                    . " Bitcoins" );
                $self->redirect_to( '/' );
                return;
            };

            my $float_amount = AmountToJSON( $amount );
            $self->bitcoin->SendFrom( $account => $address => $float_amount )
                ->merge( $self->ip_increment )
                ->then( sub {
                    $self->flash( message => 
                        "$float_amount BTC sent to $address" );
                    # Remove the POST request from the browser cache
                    $self->redirect_to( '/' );
                });
        })->persist;
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
