package Mojocoin::Faucet;

use Mojo::Base 'Mojolicious';

use Mojocoin::BitcoinClient;

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

    my $r = $self->routes;

    $r->get( '/' )->to( 'controller#home' );
    $r->get( '/about' )->to( 'controller#about' );
    $r->post( '/request' )->to( 'controller#request' );
    $r->get( '/qrcode/*string' )->to( 'controller#qrcode' );

}

1;
