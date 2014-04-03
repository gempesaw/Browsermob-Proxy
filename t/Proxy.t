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

my $proxy = $bmp->create_proxy();

isa_ok($proxy, 'Browsermob::Proxy');


done_testing;
