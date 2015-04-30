#! /usr/bin/perl

use strict;
use warnings;
use Browsermob::Proxy;
use LWP::UserAgent;
use Test::Spec;

describe 'Modifying headers' => sub {
    my $proxy;
    my $ua;
    before each => sub {
        $proxy = Browsermob::Proxy->new(
            server_addr=>"10.10.2.174",
#            trace=>"2"
        );
        $ua = LWP::UserAgent->new;
    };

    it 'Modify header' => sub {
        $proxy->filter_request(
            payload => "request.headers().add('User-Agent', 'My-Custom-User-Agent-String 1.0');"
        );
        $ua->proxy($proxy->ua_proxy);
        $ua->get("http://www.google.com");
        my $har = $proxy->har;
        use Data::Dumper;
        print Dumper $har->{log}->{entries};
    };
};

runtests;