#! /usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::LWP::UserAgent;
use Browsermob::Server;
use Net::Ping;

my $binary = '/opt/browsermob-proxy-2.0-beta-9/bin/browsermob-proxy';
plan skip_all => "Skipping server tests; no binary found" unless -f $binary;

my $p = Net::Ping->new();
my $port = 63637;
$p->port_number($port);

my $bmp = Browsermob::Server->new(
    path => $binary,
    port => $port
);

isa_ok($bmp, 'Browsermob::Proxy');

$bmp->start;
ok($p->ping('localhost'), 'server started!');

# $bmp->stop;
# ok(not $p->ping('localhost', 1), 'server stopped!');

done_testing;
