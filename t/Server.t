#! /usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::LWP::UserAgent;
use Browsermob::Server;
use Net::Ping;

SKIP: {
    my $binary = 'bin/browsermob-proxy';
    skip "Skipping server tests; no binary found", 2 unless -f $binary;

    my $p = Net::Ping->new();
    my $port = 63637;
    $p->port_number($port);

    my $bmp = Browsermob::Server->new(
        path => $binary,
        port => $port
    );

    isa_ok($bmp, 'Browsermob::Server');

    $bmp->start unless -f $binary;
    ok($p->ping('localhost'), 'server started!');
}

FIND_OPEN_PORT: {
    my $tua = Test::LWP::UserAgent->new;
    $tua->map_response(
        qr/proxy/,
        HTTP::Response->new(
            '200',
            'OK',
            ['Content-Type' => 'text/json'],
            '{"proxyList":[{"port":0},{"port":2}]}'
        ));

    my $bmp = Browsermob::Server->new(
        ua => $tua
    );

    my $open_port = $bmp->find_open_port(0..10);
    cmp_ok($open_port, 'eq', 1, 'can find the lowest open port');

    my $tua2 = Test::LWP::UserAgent->new;
    $tua2->map_response(
        qr/proxy/,
        HTTP::Response->new(
            '200',
            'OK',
            ['Content-Type' => 'text/json'],
            '{"proxyList":[]}'
        ));

    $bmp = Browsermob::Server->new(
        ua => $tua2
    );

    $open_port = $bmp->find_open_port(0..10);
    cmp_ok($open_port, 'eq', 0, 'choose the first port when none are open');
}



# $bmp->stop;
# ok(not $p->ping('localhost', 1), 'server stopped!');

done_testing;
