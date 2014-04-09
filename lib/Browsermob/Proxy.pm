package Browsermob::Proxy;

# ABSTRACT: Perl client for the proxies created by the Browsermob server
use Moo;
use Carp;
use JSON;
use Net::HTTP::Spore;
use Net::HTTP::Spore::Middleware::DefaultParams;

=for markdown [![Build Status](https://travis-ci.org/gempesaw/Browsermob-Proxy.svg?branch=master)](https://travis-ci.org/gempesaw/Browsermob-Proxy)

=head1 SYNOPSIS

Standalone:

    my $proxy = Browsermob::Proxy->new(
        server_port => 9090
        # port => 9092
    );

    print $proxy->port;
    $proxy->new_har('Google');
    # create network traffic across your port
    $proxy->har; # returns a HAR as a hashref, converted from JSON

with L<Browsermob::Server>:

    my $server = Browsermob::Server->new(
        server_port = 9090
    );
    $server->start; # ignore if your server is already running

    my $proxy = $server->create_proxy;
    $proxy->new_har('proxy from server!');

=head1 DESCRIPTION

From L<http://bmp.lightbody.net/>: BrowserMob proxy is based on
technology developed in the Selenium open source project and a
commercial load testing and monitoring service originally called
BrowserMob and now part of Neustar.

It can capture performance data for web apps (via the HAR format), as
well as manipulate browser behavior and traffic, such as whitelisting
and blacklisting content, simulating network traffic and latency, and
rewriting HTTP requests and responses.

This module is a Perl client interface to interact with the server and
its proxies. It uses L<Net::HTTP::Spore>. You can use
L<Browsermob::Server> to manage the server itself in addition to using
this module to handle the proxies.

=cut

my $spec = {
    name => 'BrowserMob Proxy',
    formats => ['json'],
    version => '0.01',
    methods => {
        get_proxies => {
            method => 'GET',
            path => '/',
            description => 'Get a list of ports attached to ProxyServer instances managed by ProxyManager'
        },
        create => {
            method => 'POST',
            path => '/',
            optional_params => [
                'port'
            ],
            description => 'Create a new proxy. Returns a JSON object {"port": your_port} on success"'
        },
        delete_proxy => {
            method => 'DELETE',
            path => '/:port',
            required_params => [
                'port'
            ],
            description => 'Shutdown the proxy and close the port'
        },
        create_new_har => {
            method => 'PUT',
            path => '/:port/har',
            optional_params => [
                'initialPageRef',
                'captureHeaders',
                'captureContent',
                'captureBinaryContent'
            ],
            required_params => [
                'port'
            ],
            description => 'creates a new HAR attached to the proxy and returns the HAR content if there was a previous HAR.'
        },
        retrieve_har => {
            method => 'GET',
            path => '/:port/har',
            description => 'returns the JSON/HAR content representing all the HTTP traffic passed through the proxy'
        }
    }
};

=attr server_port

Required during manual instantiation. Indicate at what localhost port
we should expect a Browsermob Server to be running.

    my $proxy = Browsermob::Proxy->new(server_port => 8080);

=cut

has server_port => (
    is => 'ro',
    required => 1
);

=attr port

Optional: When instantiating a proxy, you can choose the proxy port on
your own, or let it automatically assign you a port for the proxy.

    my $proxy = Browsermob::Proxy->new(
        server_port => 8080
        port => 9091
    );

=cut

has port => (
    is => 'rw',
    lazy => 1,
    predicate => 'has_port',
    default => sub { '' }
);

has mock => (
    is => 'rw',
    lazy => 1,
    predicate => 'has_mock',
    default => sub { '' }
);

has _spore => (
    is => 'ro',
    lazy => 1,
    builder => sub {
        my $self = shift;
        my $client = Net::HTTP::Spore->new_from_string(
            to_json($self->_spec),
            # trace => 1
        );
        $client->enable('Format::JSON');

        if ($self->has_port) {
            $client->enable('DefaultParams', default_params => {
                port => $self->port
            });
        }

        if ($self->has_mock) {
            # The Mock middleware ignores any middleware enabled after
            # it; make sure to enable everything else first.
            $client->enable('Mock', tests => $self->mock);
        }

        return $client;
    },
    handles => [keys $spec->{methods}]
);

has _spec => (
    is => 'ro',
    lazy => 1,
    builder => sub {
        my $self = shift;
        $spec->{base_url} = 'http://127.0.0.1:' . $self->server_port . '/proxy';
        return $spec;
    }
);

sub BUILD {
    my ($self, $args) = @_;
    my $res = $self->create;

    unless ($self->has_port) {
        $self->port($res->body->{port});
        $self->_spore->enable('DefaultParams', default_params => {
            port => $self->port
        });
    }
}

=method new_har

After creating a proxy, C<new_har> creates a new HAR attached to the
proxy and returns the HAR content if there was a previous one. If no
argument is passed, the initial page ref will be "Page 1"; you can
also pass a string to choose your own initial page ref.

    $proxy->new_har;
    $proxy->new_har('Google');

=cut

sub new_har {
    my ($self, $initial_page_ref) = @_;
    my $payload = {};

    croak "You need to create a proxy first!" unless $self->has_port;
    if (defined $initial_page_ref) {
        $payload->{initialPageRef} = $initial_page_ref;
    }

    $self->_spore->create_new_har(payload => $payload);
}

=method har

After creating a proxy and initiating a C<new_har>, you can retrieve
the contents of the current HAR with this method. It returns a hashref
HAR, and may in the future return an isntance of L<Archive::HAR>.

    my $har = $proxy->har;
    print Dumper $har->{log}->{entries}->[0];

=cut

sub har {
    my ($self) = @_;

    croak "You need to create a proxy first!" unless $self->has_port;
    return $self->_spore->retrieve_har->body;
}

sub DESTROY {
    my $self = shift;
    $self->delete_proxy;
}

1;

=head1 SEE ALSO

http://bmp.lightbody.net/
https://github.com/lightbody/browsermob-proxy
Browsermob::Server

=cut
