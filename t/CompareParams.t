#! /usr/bin/perl

use strict;
use warnings;
use Browsermob::Server;
use IO::Socket::INET;
use LWP::UserAgent;
use Test::Spec;
use Test::Deep;
use Browsermob::Proxy::CompareParams qw/cmp_request_params convert_har_params_to_hash/;

describe 'Request parameter comparison' => sub {
    my ($requests, $assert);

    before each => sub {
        $requests = [{
            request => {
                queryString => [
                    {
                        name => 'query',
                        value => 'string'
                    },
                ]
            }
        }, {
            request => {
                queryString => [
                    {
                        name => 'query2',
                        value => 'string2'
                    },
                    {
                        name => 'query3',
                        value => 'string3'
                    }
                ]
            }
        }];
    };

    it 'should know how to convert har params' => sub {
        my $converted = convert_har_params_to_hash($requests);
        my $expected = [
            {
                query => 'string'
            },
            {
                query2 => 'string2',
                query3 => 'string3'
            },
        ];
        cmp_deeply($converted, $expected);
    };

    it 'should pass on exact matches: all keys, all values' => sub {
        $assert = { query => 'string' };
        ok(cmp_request_params($requests, $assert));

        $assert = {
            query2 => 'string2',
            query3 => 'string3'
        };
        ok(cmp_request_params($requests, $assert));
    };

    it 'should pass on assert in multiple requests' => sub {
        $requests = [{
            request => {
                queryString => [{
                    name => 'both',
                    value => 'reqs'
                }]
            }
        },{
            request => {
                queryString => [{
                    name => 'both',
                    value => 'reqs'
                }]
            }
        }];

        $assert = { both => 'reqs' };
        ok(cmp_request_params($requests, $assert));
    };


    it 'should pass on a subset match: some keys' => sub {
        $assert = { query2 => 'string2' };
        ok(cmp_request_params($requests, $assert));
    };


    it 'should fail on assert missing key' => sub {
        $assert = { missing => 'string' };
        ok( ! cmp_request_params($requests, $assert));
    };

    it 'should fail on assert with incorrect value' => sub {
        $assert = { query => 'incorrect' };
        ok( ! cmp_request_params($requests, $assert));
    };

    it 'should fail on an assert with an extra k/v pair' => sub {
        $assert = {
            query => 'string',
            missing => 'pair'
        };
        ok( ! cmp_request_params($requests, $assert));
    };
};

SKIP: {
    my $server = Browsermob::Server->new( port => 8081 );
    my $has_connection = IO::Socket::INET->new(
        PeerAddr => 'www.perl.org',
        PeerPort => 80,
        Timeout => 5
    );

    skip 'No server found for e2e tests', 2
      unless $server->_is_listening(5) and $has_connection;

    describe 'E2E Comparing params' => sub {
        my ($ua, $proxy, $har);

        before each => sub {
            $ua = LWP::UserAgent->new;
            $proxy = $server->create_proxy;
            $ua->proxy($proxy->ua_proxy);
            $ua->get('http://www.perl.org/?query=string');

            $har = $proxy->har;
        };

        it 'should properly match traffic' => sub {
            ok(cmp_request_params($har, { query => 'string' }));
        };

        it 'should reject non-matching traffic' => sub {
            ok( ! cmp_request_params($har, { query2 => 'string2' }));
        };
    };
}

runtests;
