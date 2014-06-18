package Browsermob::Proxy;
$Browsermob::Proxy::VERSION = '0.07';
# ABSTRACT: Perl client for the proxies created by the Browsermob server
use Moo;
use Carp;
use JSON;
use Net::HTTP::Spore;
use Net::HTTP::Spore::Middleware::DefaultParams;


my $spec = {
    name => 'BrowserMob Proxy',
    formats => ['json'],
    version => '0.01',
    # server name and port are constructed in the _spore builder
    # base_url => '/proxy',
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
            required_params => [
                'port'
            ],
            description => 'returns the JSON/HAR content representing all the HTTP traffic passed through the proxy'
        },
        auth_basic => {
            method => 'POST',
            path => '/:port/auth/basic/:domain',
            required_params => [
                'port',
                'domain'
            ],
            description => 'Sets automatic basic authentication for the specified domain'
        }
    }
};


has server_addr => (
    is => 'rw',
    default => sub { '127.0.0.1' }
);



has server_port => (
    is => 'rw',
    default => sub { 8080 }
);


has port => (
    is => 'rw',
    lazy => 1,
    predicate => 'has_port',
    default => sub { '' }
);


has trace => (
    is => 'ro',
    default => sub { 0 }
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
            trace => $self->trace
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
    handles => [keys %{ $spec->{methods} }]
);

has _spec => (
    is => 'ro',
    lazy => 1,
    builder => sub {
        my $self = shift;
        $spec->{base_url} = 'http://' . $self->server_addr . ':' . $self->server_port . '/proxy';
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


sub new_har {
    my ($self, $initial_page_ref) = @_;
    my $payload = {};

    croak "You need to create a proxy first!" unless $self->has_port;
    if (defined $initial_page_ref) {
        $payload->{initialPageRef} = $initial_page_ref;
    }

    $self->_spore->create_new_har(payload => $payload);
}


sub har {
    my ($self) = @_;

    croak "You need to create a proxy first!" unless $self->has_port;
    return $self->_spore->retrieve_har->body;
}


sub selenium_proxy {
    my ($self, $initiate_manually) = @_;
    $self->new_har unless $initiate_manually;

    return {
        proxyType => 'manual',
        httpProxy => 'http://' . $self->server_addr . ':' . $self->port,
        sslProxy => 'http://' . $self->server_addr . ':' . $self->port
    };
}


sub ua_proxy {
    my ($self, $initiate_manually) = @_;
    $self->new_har unless $initiate_manually;

    return ('http', 'http://' . $self->server_addr . ':' . $self->port);
}


sub add_basic_auth {
    my ($self, $args) = @_;
    foreach (qw/domain username password/) {
        croak "$_ is a required parameter for add_basic_auth"
        unless exists $args->{$_};
    }

    $self->auth_basic(
        domain => delete $args->{domain},
        payload => $args
    );

}

sub DESTROY {
    my $self = shift;
    $self->delete_proxy;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Browsermob::Proxy - Perl client for the proxies created by the Browsermob server

=for markdown [![Build Status](https://travis-ci.org/gempesaw/Browsermob-Proxy.svg?branch=master)](https://travis-ci.org/gempesaw/Browsermob-Proxy)

=head1 VERSION

version 0.07

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
        server_port => 9090
    );
    $server->start; # ignore if your server is already running

    my $proxy = $server->create_proxy;
    $proxy->new_har('proxy from server!');

=head1 DESCRIPTION

From L<http://bmp.lightbody.net/>:

=over 4

BrowserMob proxy is based on technology developed in the Selenium open
source project and a commercial load testing and monitoring service
originally called BrowserMob and now part of Neustar.

It can capture performance data for web apps (via the HAR format), as
well as manipulate browser behavior and traffic, such as whitelisting
and blacklisting content, simulating network traffic and latency, and
rewriting HTTP requests and responses.

=back

This module is a Perl client interface to interact with the server and
its proxies. It uses L<Net::HTTP::Spore>. You can use
L<Browsermob::Server> to manage the server itself in addition to using
this module to handle the proxies.

=head1 ATTRIBUTES

=head2 server_addr

Optional: specify where the proxy server is; defaults to 127.0.0.1

=head2 server_port

Optional: Indicate at what port we should expect a Browsermob Server
to be running; defaults to 8080

    my $proxy = Browsermob::Proxy->new(server_port => 8080);

=head2 port

Optional: When instantiating a proxy, you can choose the proxy port on
your own, or let it automatically assign you a port for the proxy.

    my $proxy = Browsermob::Proxy->new(
        server_port => 8080
        port => 9091
    );

=head2 trace

Set Net::HTTP::Spore's trace option; defaults to 0; set it to 1 to see
headers and 2 to see headers and responses. This can only be set during
construction.

    my $proxy = Browsermob::Proxy->new( trace => 2 );

=head1 METHODS

=head2 new_har

After creating a proxy, C<new_har> creates a new HAR attached to the
proxy and returns the HAR content if there was a previous one. If no
argument is passed, the initial page ref will be "Page 1"; you can
also pass a string to choose your own initial page ref.

    $proxy->new_har;
    $proxy->new_har('Google');

=head2 har

After creating a proxy and initiating a C<new_har>, you can retrieve
the contents of the current HAR with this method. It returns a hashref
HAR, and may in the future return an isntance of L<Archive::HAR>.

    my $har = $proxy->har;
    print Dumper $har->{log}->{entries}->[0];

=head2 selenium_proxy

Generate the proper capabilities for use in the constructor of a new
Selenium::Remote::Driver object.

    my $proxy = Browsermob::Proxy->new;
    my $driver = Selenium::Remote::Driver->new(
        browser_name => 'chrome',
        proxy        => $proxy->selenium_proxy
    );
    $driver->get('http://www.google.com');
    print Dumper $proxy->har;

N.B.: C<selenium_proxy> will AUTOMATICALLY call L</new_har> for you
initiating an unnamed har, unless you pass it something truthy.

    my $proxy = Browsermob::Proxy->new;
    my $driver = Selenium::Remote::Driver->new(
        browser_name => 'chrome',
        proxy        => $proxy->selenium_proxy(1)
    );
    # later
    $proxy->new_har;
    $driver->get('http://www.google.com');
    print Dumper $proxy->har;

=head2 ua_proxy

Generate the proper arguments for the proxy method of
L<LWP::UserAgent>. By default, C<ua_proxy> will initiate a new har for
you automatically, the same as L</selenium_proxy> does. If you want to
initialize the har yourself, pass in something truthy.

    my $proxy = Browsermob::Proxy->new;
    my $ua = LWP::UserAgent->new;
    $ua->proxy($proxy->ua_proxy);

=head2 add_basic_auth

Set up automatic Basic authentication for a specified domain. Accepts
as input a HASHREF with the keys C<domain>, C<username>, and
C<password>. For example,

    $proxy->add_basic_auth({
        domain => '.google.com',
        username => 'username',
        password => 'password'
    });

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<http://bmp.lightbody.net/|http://bmp.lightbody.net/>

=item *

L<https://github.com/lightbody/browsermob-proxy|https://github.com/lightbody/browsermob-proxy>

=item *

L<Browsermob::Server|Browsermob::Server>

=back

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
https://github.com/gempesaw/Browsermob-Proxy/issues

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

Daniel Gempesaw <gempesaw@gmail.com>

=cut
