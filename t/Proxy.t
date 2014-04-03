#! /usr/bin/perl

use strict;
use warnings;
use Test::More;
use Browsermob::Server;

my $binary = '/opt/browsermob-proxy-2.0-beta-9/bin/browsermob-proxy';
plan skip_all => "Skipping server tests; no binary found" unless -f $binary;

my $bmp = Browsermob::Server->new(
    path => $binary,
    port => 63638
);
$bmp->start;

PROXY_PORT: {
    my $proxy = $bmp->create_proxy();

    isa_ok($proxy, 'Browsermob::Proxy');
    ok(defined $proxy->port, 'Our new proxy has its own port!');

    my $choose = $bmp->create_proxy(port => 9092);
    cmp_ok($choose->port, '==', 9092, 'We can pick our own ports!');
}

done_testing;
