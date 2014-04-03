#! /usr/bin/perl

use strict;
use warnings;
use Test::More;
use JSON;
use Browsermob::Server;

my $binary = '/opt/browsermob-proxy-2.0-beta-9/bin/browsermob-proxy';
my $port = 63638;
plan skip_all => "Skipping server tests; no binary found" unless -f $binary;

my $bmp = Browsermob::Server->new(
    path => $binary,
    port => $port
);
$bmp->start;

PROXY_PORT: {
    my $proxy = Browsermob::Proxy->new(
        server_port => $port
    );

    isa_ok($proxy, 'Browsermob::Proxy');
    ok(defined $proxy->port, 'Our new proxy has its own port!');

    my $choose = $bmp->create_proxy(port => 9092);
    cmp_ok($choose->port, '==', 9092, 'We can pick our own ports!');
}

my $proxy_list = $bmp->get_proxies->{proxyList};
ok(scalar @$proxy_list eq 0, 'Proxies automatically delete themselves');

HAR: {
    my $proxy = Browsermob::Proxy->new(
        server_port => $port
    );

    $proxy->new_har('Google');
}

$bmp->stop;
done_testing;
