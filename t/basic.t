use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new( 'Mojocoin::Faucet' );
$t->get_ok('/')->status_is(200)->content_like( qr/Faucet/i );

done_testing();
