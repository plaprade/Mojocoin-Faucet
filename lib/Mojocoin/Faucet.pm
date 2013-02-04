package Mojocoin::Faucet;

use Mojo::Base 'Mojolicious';

use Mojocoin::BitcoinClient;
use Mojo::Redis;
use Digest::SHA qw( sha256 );

use AnyEventX::CondVar;
use AnyEventX::CondVar::Util qw( :all );

# This method will run once at server start
sub startup {
    my $self = shift;

    $self->secret( `echo -n \`cat etc/secret.key\`` );

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');
    $self->plugin('DefaultHelpers');
    $self->plugin('TagHelpers');

    # Mojolicious helper. Returns a handle to the HTTP JSON RPC
    # bitcoin client.
    $self->helper( bitcoin => sub {
        state $bitcoin = Mojocoin::BitcoinClient->new(
            url => 'http://127.0.0.1:18332',
            username => `echo -n \`cat etc/username.key\``,
            password => `echo -n \`cat etc/password.key\``,
        );
    });

    # Mojolicious helper. Returns a handle to the Redis server.
    $self->helper( redis => sub {
        state $redis = Mojo::Redis->new( 
            server => '127.0.0.1:6379'
        );    
    });

    # Checks if the requests IP address is authorized
    # to to a withdrawal. Returns a condition variable. 
    $self->helper( ip_authorized => sub {
        my $self = shift;
        cv_build {
            $self->redis->hget( testnetip => 
                $self->tx->remote_address => $_ );
        } cv_then {
            my ( $redis, $value ) = ( shift, shift || 0 );
            # Maximum 10 withdrawals per IP address
            $value < 10;
        };
    });

    # Increments the withdrawal counter of the current IP addesss.
    # Returns a condition variable.
    $self->helper( ip_increment => sub {
        my $self = shift;
        my $ip = $self->tx->remote_address;
        cv_build {
            $self->redis->hget( testnetip => $ip => $_ );
        } cv_then {
            my ( $redis, $value ) = ( shift, shift || 0 );
            $self->redis->hset( testnetip => $ip => $value + 1 );
        }
    });

    my $r = $self->routes;

    $r->get( '/' )->to( 'controller#home' );
    $r->get( '/about' )->to( 'controller#about' );
    $r->post( '/request' )->to( 'controller#request' );
    $r->get( '/qrcode/*string' )->to( 'controller#qrcode' );

}

1;
