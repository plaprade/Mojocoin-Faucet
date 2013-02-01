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

    $self->helper( bitcoin => sub {
        state $bitcoin = Mojocoin::BitcoinClient->new(
            url => 'http://127.0.0.1:18332',
            username => `echo -n \`cat etc/username.key\``,
            password => `echo -n \`cat etc/password.key\``,
        );
    });

    $self->helper( salt => sub {
        state $salt = `echo -n \`cat etc/salt.key\``;
    });

    $self->helper( redis => sub {
        state $redis = Mojo::Redis->new( 
            server => '127.0.0.1:6379'
        );    
    });

    $self->helper( ip_authorized => sub {
        my $self = shift;
        my $ip = $self->tx->remote_address;
        my $hash = unpack( 'H*', sha256( $ip . $self->salt ) );
        cv_build {
            $self->redis->hget( testnetip => $hash => $_ );
        } cv_then {
            my $redis = shift;
            my $value = shift || 0;
            $value < 10;
        };
    });

    $self->helper( ip_increment => sub {
        my $self = shift;
        my $ip = $self->tx->remote_address;
        my $hash = unpack( 'H*', sha256( $ip . $self->salt ) );
        cv_build {
            $self->redis->hget( testnetip => $hash => $_ );
        } cv_then {
            my $redis = shift;
            my $value = shift || 0;
            $self->redis->hset( testnetip => $hash => ++$value );
        }
    });

    my $r = $self->routes;

    $r->get( '/' )->to( 'controller#home' );
    $r->get( '/about' )->to( 'controller#about' );
    $r->post( '/request' )->to( 'controller#request' );
    $r->get( '/qrcode/*string' )->to( 'controller#qrcode' );

}

1;
