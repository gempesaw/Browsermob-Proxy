#! /usr/bin/perl

use strict;
use warnings;
use Test::More;
use JSON;
use LWP::UserAgent;
use Browsermob::Proxy;

my $server_port = 63638;
my $port = 9091;

SPECIFY_PORT: {
    my $proxy = Browsermob::Proxy->new(
        server_port => $server_port,
        port => $port,
        mock => generate_mock_server()
    );

    ok(defined $proxy->port, 'created a proxy with our own port');
    if ($proxy->has_mock) {
        cmp_ok($proxy->port, 'eq', $port, 'on the default port');
    }

    my $res = $proxy->has_mock ? $proxy->delete_proxy : { body => ""};
    ok($res->{body} eq '', 'proxy deletes itself');
    # ok($delete_count eq 1, 'proxy deletes self when taken out of scope');
}

NO_PORT: {
    my $proxy = Browsermob::Proxy->new(
        server_port => $port,
        mock => generate_mock_server()
    );

    isa_ok($proxy, 'Browsermob::Proxy');
    ok(defined $proxy->port, 'Our new proxy has its own port!');
}

HAR: {
  CREATE_UNNAMED: {
        my $har_server = generate_mock_server();

        $har_server->{'/proxy/' . $port . '/har'} = sub {
            my $req = shift;
            ok($req->method eq 'PUT', 'creating a har uses PUT');
            ok($req->body eq '{}', 'unnamed har body is empty');
            $req->new_response(200, ['Content-Type' => 'application/json'], "");
        };

        my $proxy = Browsermob::Proxy->new(
            server_port => $server_port,
            port => $port,
            mock => $har_server
        );

        my $res = $proxy->new_har;
    }

  CREATE_NAMED: {
        my $har_server = generate_mock_server();

        $har_server->{'/proxy/' . $port . '/har'} = sub {
            my $req = shift;
            ok($req->method eq 'PUT', 'creating a named har uses PUT');
            ok($req->body eq '{"initialPageRef":"Google"}', 'body of new har has name');
            $req->new_response(200, ['Content-Type' => 'application/json'], "");
        };

        my $proxy = Browsermob::Proxy->new(
            server_port => $server_port,
            port => $port,
            mock => $har_server
        );

        my $res = $proxy->new_har('Google');
        ok($res->body eq "", 'got the expected response back when creating a named har');
    }

  RETRIEVE: {
        my $har_server = generate_mock_server();
        $har_server->{'/proxy/' . $port . '/har'} = sub {
            my $req = shift;
            ok($req->method eq 'GET', 'retrieving a har via GET');
            $req->new_response(200, ['Content-Type' => 'application/json'], '{"sample": "har"}');
        };

        my $proxy = Browsermob::Proxy->new(
            server_port => $server_port,
            port => $port,
            mock => $har_server
        );

        my $res = $proxy->har;
        isa_ok($res->body, 'HASH', 'the retrieved har is a hash');
    }
}

sub generate_mock_server {
    my $mock_port = shift || $port;

    return {
        '/proxy/' => sub {
            my $req = shift;
            if ($req->method eq 'POST') {
                use Data::Dumper; use DDP;
                my $res = {
                    port => $mock_port
                };
                return $req->new_response(200, ['Content-Type' => 'application/json'], to_json($res));
            }
        },

        '/proxy/' . $mock_port => sub {
            my ($req) = @_;

            my %params;
            eval {
                %params = @{ $req->get_from_env("spore.params") };
            };

            if ($req->method eq 'DELETE') {
                die unless $params{port};
                return $req->new_response(200, ['Content-Type' => 'application/json'], "");
            }
        }
    }
}

done_testing;
