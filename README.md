# Mojocoin::Faucet - Bitcoin Faucet Implementation

Mojocoin::Faucet is a lightweight implementation of a Bitcoin faucet
in Perl. It is built on top of the popular Mojolicious web framework
and uses Redis as an in-memory key/value data store. Mojocoin::Faucet
delegates most bitcoin-related tasks to the original Satoshi bitcoind
client. We use bootstrap from twitter for CSS designs. Here is a wrap
up of the technologies used:

- bitcoind [http://github.com/bitcoin/bitcoin](http://github.com/bitcoin/bitcoin)
- Mojolicious [http://mojolicio.us](http://mojolicio.us)
- Redis [http://redis.io](http://redis.io)
- Twitter Bootstrap [http://twitter.github.com/bootstrap](http://twitter.github.com/bootstrap)

## Frameworks & Tools

Mojolicious is a cooperative multitasking web framework as it runs on
a single-process event loop (usually [EV](http://search.cpan.org/perldoc?EV)). You can leverage the
power of GNU/Linux pre-forking using the built-in Hypnotoad web
server.

Mojolicious is an asynchronous web framework. The programming style is
mostly callback-oriented. You install listeners on the event loop and
provide callbacks for specifying your program continuations. This
shouldn't been too alien if you have some javascript or node.js
background. 

To make asynchronous programming easier with Mojolicious, we designed
the [Continuum](http://github.com/ciphermonk/Continuum) framework. It
allows us to run asynchronous commands in parallel and provide
merge-point callbacks very easily.  This should be fairly simple to
understand: 

```perl
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
```

To communicate with the Satoshi Bitcoin implementation, I wrote
[Continuum::BitcoinRPC](http://github.com/ciphermonk/Continuum-BitcoinRPC).
It is a simple JSON/RPC interface to bitcoind.

## Installation

Upgrade to Perl v5.14 if you haven't already. This program requires some
features that are only well supported from that version.

You will need the following Perl modules from github:

- [Continuum](http://github.com/ciphermonk/Continuum)
- [Continuum::BitcoinRPC](http://github.com/ciphermonk/Continuum-BitcoinRPC)
- [Continuum::Redis](http://github.com/ciphermonk/Continuum-Redis)
- [anyevent-jsonrpc-perl](http://github.com/ciphermonk/anyevent-jsonrpc-perl)
This is a fork from [AnyEvent::JSONRPC::HTTP::Client](http://search.cpan.org/perldoc?AnyEvent::JSONRPC::HTTP::Client) fixing a small
issue with error handling in the HTTP client. We only use the HTTP
client from this package.
- [Mojocoin::Faucet](http://github.com/ciphermonk/Mojocoin-Faucet) (this
project)

And _at least_ the following modules from CPAN:

- [Mojolicious](http://search.cpan.org/perldoc?Mojolicious)
- [AnyEvent](http://search.cpan.org/perldoc?AnyEvent)
- [EV](http://search.cpan.org/perldoc?EV) (recommended event loop library)
- [Mojo::Redis](http://search.cpan.org/perldoc?Mojo::Redis)

You may be missing upstream dependencies from CPAN.  Just install them as you
go.

You'll need to install bitcoind and configure it to use RPC:

[bitcoin.org](http://bitcoin.org)

The Faucet needs to be able to communicate with bitcoind through RPC.  In the
project root, create a directory named `etc` and two files called
`username.key` and `password.key` containing the bitcoin RPC username and
password respectively. This is fine for a testnet faucet, but you may need to
apply better security if you wish to run a production faucet. 

Again in `etc`, create a file called `secret.key` with a random
password. This secret is used to sign session cookies. However, we
don't use sessions yet in the faucet.

Finally, install [Redis.io](http://redis.io) and make it available on
the localhost interface, port 6379 (default port). If you change the
Redis network settings, you'll need to update the Faucet.pm file. 

To launch the server, use the following commands from the project root:

#### Development

morbo script/mojocoin-faucet.pl -l http://127.0.0.1:3000

#### Production (single process)

script/mojocoin-faucet.pl daemon -l http://\*:80

You can use Hypnotoad for a prefork Unix-optimized server, Although it has not
been tested with the faucet yet.  The default Mojolicious server should be
enough since the application is optimized for asynchronous IO.

## Bugs

Please report any bugs in the projects bug tracker:

[http://github.com/ciphermonk/Mojocoin-Faucet/issues](http://github.com/ciphermonk/Mojocoin-Faucet/issues)

You can also submit a patch.

## Contributing

We're glad you want to contribute! It's simple:

- Fork Mojocoin::Faucet
- Create a branch `git checkout -b my_branch`
- Commit your changes `git commit -am 'comments'`
- Push the branch `git push origin my_branch`
- Open a pull request

## Supporting

Like what you see? You can support the project by donating in
[Bitcoins](http://www.weusecoins.com/) to:

__17YWBJUHaiLjZWaCyPwcV8CJDpfoFzc8Gi__
