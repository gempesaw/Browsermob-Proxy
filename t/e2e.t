#! /usr/bin/perl

use strict;
use warnings;
use JSON;
use Net::Ping;
use Test::More;
use Browsermob::Proxy;

my $har = {};
my $server_port = 63638;

if (is_proxy_server_running($server_port)) {
    my $proxy = Browsermob::Proxy->new(
        server_port => $server_port
    );

    $proxy->new_har;

    my $generate_traffic = 'curl -x http://localhost:' . $proxy->port .' http://www.google.com > /dev/null 2>&1';
    `$generate_traffic`;

    $har = $proxy->har;
    my $entry = $har->{log}->{entries}->[0];

    cmp_ok($entry->{request}->{url}, '=~', qr{http://www\.google\.com}, 'verified expected url');
}

sub is_proxy_server_running {
    my $port = shift;
    my $p = Net::Ping->new("tcp", 2);
    $p->port_number($port);
    unless ($p->ping('localhost')) {
        plan skip_all => 'Browsermob server is not running on localhost:' . $port;
        exit;
    }

    return 1;
}

done_testing;
