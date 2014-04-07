package Browsermob::Server;

# ABSTRACT: Perl client to control the Browsermob Proxy server
use strict;
use warnings;
use Moo;
use Carp;
use JSON;
use LWP::UserAgent;
use IO::Socket::INET;
use Browsermob::Proxy;

=head1 SYNOPSIS

    my $bmp = Browsermob::Server->new(
        path => '/path/to/browsermob-proxy'
    );
    $bmp->start;
    my $proxy = $bmp->create_proxy;

    print $proxy->port;
    $proxy->create_har('Test');
    # generate traffic across your port
    $proxy->har; # returns a HAR

=cut

=head1 DESCRIPTION

From L<http://bmp.lightbody.net/>: BrowserMob proxy is based on
technology developed in the Selenium open source project and a
commercial load testing and monitoring service originally called
BrowserMob and now part of Neustar.

It can capture performance data for web apps (via the HAR format), as
well as manipulate browser behavior and traffic, such as whitelisting
and blacklisting content, simulating network traffic and latency, and
rewriting HTTP requests and responses.

This module is a Perl client interface to control the server and its
proxies. It uses L<Net::HTTP::Spore>.

=cut

=attr path

Required. The path to the browsermob_proxy binary.

=cut

has path => (
    is => 'rw',
    required => 1
);

=attr port

Optional. The port on which the proxy server should run. This is not
the port that you should have other clients connect.

=cut

has server_port => (
    is => 'rw',
    init_arg => 'port',
    default => sub { 8080 }
);

has _pid => (
    is => 'rw',
    init_arg => undef,
    default => sub { '' }
);

=method start

Start a browsermob proxy on C<port>. Starting the server does not create
any proxies.

=cut

sub start {
    my $self = shift;

    defined ($self->_pid(fork)) or die "Error starting server: $!";
    if ($self->_pid) {
        # The parent knows about the child pid
        die "Error starting server: $!" unless $self->_is_listening;
    }
    else {
        # If I don't know the pid, then I'm the child and we should
        # exec to replace ourselves with the proxy
        my $cmd = 'sh ' . $self->path . ' -port ' . $self->server_port . ' 2>&1 > /dev/null';
        exec($cmd);
        exit(0);
    }
}

=method stop

Stop the forked browsermob-proxy server. This does not work all the
time, although the server seems to get GC'd all on its own, even after
ignoring a C<SIGTERM>.

=cut

sub stop {
    my $self = shift;
    kill('SIGKILL', $self->_pid) and waitpid($self->_pid, 0);
}

=method create_proxy

After starting the server, or connecting to an existing one, use
C<create_proxy> to get a proxy that you can use with your tests. No
proxies actually exist until you call create_proxy; starting the
server does not create a proxy.

    my $proxy = $bmp->create_proxy(); # returns a Browsermob::Proxy object
    my $proxy = $bmp->create_proxy(port => 1337);

=cut

sub create_proxy {
    my ($self, %args) = @_;

    my $proxy = Browsermob::Proxy->new(
        server_port => $self->server_port,
        %args
    );

    return $proxy;
}

=method get_proxies

Get a list of currently registered proxies.

    my $proxy_aref = $bmp->get_proxies->{proxyList};
    print scalar @$proxy_aref;

=cut

sub get_proxies {
    my $self = shift;
    my $ua = shift || LWP::UserAgent->new;

    my $res = $ua->get('http://localhost:' . $self->server_port . '/proxy');
    if ($res->is_success) {
        return from_json($res->decoded_content);
    }
}


sub _is_listening {
    my $self = shift;
    my $sock = undef;
    my $count = 0;
    my $limit = 60;

    while (!defined $sock && $count++ < $limit) {
        $sock = IO::Socket::INET->new(
            PeerAddr => 'localhost',
            PeerPort => $self->server_port,
        );
        select(undef, undef, undef, 0.5);
    }

    return defined $sock;
}

1;
