#!/usr/bin/env perl
use strict;
use warnings;

use Continuum::Redis;

my $redis = Continuum::Redis->new( 
    server => '127.0.0.1:6379'
);    

$redis->del( 'testnetip' )->recv;

