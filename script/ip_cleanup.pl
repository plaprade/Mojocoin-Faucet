#!/usr/bin/env perl
use strict;
use warnings;

use Mojo::Redis;
use AnyEvent;

my $redis = Mojo::Redis->new( 
    server => '127.0.0.1:6379'
);    

my $cv = AnyEvent->condvar;

$redis->del( testnetip => sub {
    $cv->send;
});

$cv->recv;

