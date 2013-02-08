package Mojocoin::Faucet;

use Mojo::Base 'Mojolicious';

use Continuum;
use Continuum::BitcoinRPC;
use Continuum::Redis;
use Mojo::Redis;
use Digest::SHA qw( sha256 );

use version; our $VERSION = version->declare("v0.0.1"); 

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
        state $bitcoin = Continuum::BitcoinRPC->new(
            url => 'http://127.0.0.1:18332',
            username => `echo -n \`cat etc/username.key\``,
            password => `echo -n \`cat etc/password.key\``,
        );
    });

    # Mojolicious helper. Returns a handle to the Redis server.
    $self->helper( redis => sub {
        state $redis = Continuum::Redis->new( 
            server => '127.0.0.1:6379'
        );    
    });

    # Checks if the requests IP address is authorized
    # to do a withdrawal. Returns a condition variable. 
    $self->helper( ip_authorized => sub {
        my $self = shift;
        my $ip = $self->tx->remote_address;
        # Maximum 10 withdrawals per IP address
        $self->redis->hget( testnetip => $ip ) < 10;
    });

    # Increments the withdrawal counter of the current IP addesss.
    # Returns a condition variable.
    $self->helper( ip_increment => sub {
        my $self = shift;
        my $ip = $self->tx->remote_address;
        $self->redis->hget( testnetip => $ip )->then( sub {
            my $value = shift || 0;
            $self->redis->hset( testnetip => $ip => $value + 1 );
        });
    });

    my $r = $self->routes;

    $r->get( '/' )->to( 'controller#home' );
    $r->get( '/about' )->to( 'controller#about' );
    $r->post( '/request' )->to( 'controller#request' );
    $r->get( '/qrcode/*string' )->to( 'controller#qrcode' );

}

1;

__END__

=head1 Mojocoin::Faucet - Bitcoin Faucet Implementation

Mojocoin::Faucet is a lightweight implementation of a Bitcoin faucet
in Perl. It is built on top of the popular Mojolicious web framework
and uses Redis as an in-memory key/value data store. Mojocoin::Faucet
delegates most bitcoin-related tasks to the original Satoshi bitcoind
client. We use bootstrap from twitter for CSS designs. Here is a wrap
up of the technologies used:

=over

=item bitcoind L<http://github.com/bitcoin/bitcoin>

=item Mojolicious L<http://mojolicio.us>

=item Redis L<http://redis.io>

=item Twitter Bootstrap L<http://twitter.github.com/bootstrap>

=back

=head2 Frameworks & Tools

Mojolicious is a cooperative multitasking web framework as it runs on
a single-process event loop (usually L<EV>). You can leverage the
power of GNU/Linux pre-forking using the built-in Hypnotoad web
server.

Mojolicious is an asynchronous web framework. The programming style is
mostly callback-oriented. You install listeners on the event loop and
provide callbacks for specifying your program continuations. This
shouldn't been too alien if you have some javascript or node.js
background. 

To make asynchronous programming easier with Mojolicious, we designed
the L<Continuum|http://github.com/ciphermonk/Continuum> framework. It
allows us to run asynchronous commands in parallel and provide
merge-point callbacks very easily.  This should be fairly simple to
understand: 

    use Continuum;
    use Continuum::BitcoinRPC # $bitcoin
    use Continuum::Redis # $redis
    
    $bitcoin->GetBalance
        ->merge( $bitcoin->ValidateAddress( $address ) )
        ->merge( $redis->hget( ip => value ) )
        ->then( sub { 
            my ( $balance, $validation, $ip ) = @_;
            # This callback is called once all 3 asynchronous
            # operations above are completed
        });

To communicate with the Satoshi Bitcoin implementation, we built
L<Continuum::BitcoinRPC|http://github.com/ciphermonk/Continuum-BitcoinRPC>.
It is a simple JSON/RPC interface to bitcoind.

=head2 Installation

Upgrade to perl v5.14 if you didn't already. We use some features that
are only really well supported from version 5.14 onwards.

You will need to grab the following Perl modules from github:

=over

=item *
L<Continuum|http://github.com/ciphermonk/Continuum>

=item *
L<Continuum::BitcoinRPC|http://github.com/ciphermonk/Continuum-BitcoinRPC>

=item *
L<Continuum::Redis|http://github.com/ciphermonk/Continuum-Redis>

=item*
L<anyevent-jsonrpc-perl|http://github.com/ciphermonk/anyevent-jsonrpc-perl>
This is a fork from L<AnyEvent::JSONRPC::HTTP::Client> fixing a small
issue with error handling in the HTTP client. We only use the HTTP
client from this package.

=item *
L<Mojocoin::Faucet|http://github.com/ciphermonk/Mojocoin-Faucet> (this
project)

=back

And I<at least> the following modules from CPAN:

=over

=item *
L<Mojolicious>

=item *
L<AnyEvent>

=item *
L<EV> (recommended event loop library)

=item * 
L<Mojo::Redis>

=back

You might be missing some other CPAN dependencies depending on your
local Perl installation. Just install them as you go.

You'll need to install bitcoind and configure it to use RPC:

L<bitcoin.org|http://bitcoin.org>

The Faucet needs to be able to communicate with bitcoind through RPC.
In the projects root, create the folder C<etc> and create two files
called C<username.key> and C<password.key> containing respectively the
bitcoin RPC username and password. This is fine for a testnet faucet,
but might need to be better secured for a production faucet. 

Again in C<etc>, create a file called C<secret.key> with a random
password. This secret is used to sign session cookies. However, we
don't use session yet in the faucet.

Finally, install L<Redis.io|http://redis.io> and make it available on
the localhost interface, port 6379 (default port). If you change the
Redis network settings, you need to update the Faucet.pm file. 

To launch the server, use the following commands from the project root:

=head4 Development

morbo script/mojocoin-faucet.pl -l http://127.0.0.1:3000

=head4 Production (single process)

script/mojocoin-faucet.pl daemon -l http://*:80

You can use the Hypnotoad server for a prefork Unix-optimized server.
It's not been tested yet however for the faucet, so hold your horses.
The single process should be plenty for now as it runs on an event
loop in cooperative multitasking mode. 

=head2 Bugs

Please report any bugs in the projects bug tracker:

L<http://github.com/ciphermonk/Mojocoin-Faucet/issues>

You can also submit a patch.

=head2 Contributing

We're glad you want to contribute! It's simple:

=over

=item * 
Fork Mojocoin::Faucet

=item *
Create a branch C<git checkout -b my_branch>

=item *
Commit your changes C<git commit -am 'comments'>

=item *
Push the branch C<git push origin my_branch>

=item *
Open a pull request

=back

=head2 Supporting

Like what you see? You can support the project by donating in
L<Bitcoins|http://www.weusecoins.com/> to:

B<17YWBJUHaiLjZWaCyPwcV8CJDpfoFzc8Gi>

=cut

