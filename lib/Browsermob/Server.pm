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

    my $server = Browsermob::Server->new(
        path => '/opt/browsermob-proxy-2.0-beta-9/bin/browsermob-proxy'
    );
    $server->start;             # ignore if your server is already started

    my $proxy = $server->create_proxy;
    my $port = $proxy->port;

    $proxy->new_har;

    # generate traffic across your port
    `curl -x http://localhost:$port http://www.google.com > /dev/null 2>&1`;

    print Dumper $proxy->har;

=head1 DESCRIPTION

This class provides a way to control the Browsermob Proxy server
within Perl. There are only a few public methods for starting and
stopping the server. You also have the option of instantiating a
server object and pointing it towards an existing BMP server on
localhost, and just using it to avoid having to pass the server_port
arg when instantiating new proxies.

=attr path

The path to the browsermob_proxy binary. If you aren't planning to
call C<start>, this is optional.

=cut

has path => (
    is => 'rw',
);

=attr server_addr

The address of the remote server where the Browsermob Proxy server is
running. This defaults to localhost.

=cut

has server_addr => (
    is => 'rw',
    default => sub { 'localhost' }
);

=attr port

The port on which the proxy server should run. This is not the port
that you should have other clients connect.

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
    die '"' . $self->path . '" is an invalid path' unless -f $self->path;

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

    my $proxy = $bmp->create_proxy; # returns a Browsermob::Proxy object
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

    my $res = $ua->get('http://' . $self->server_addr . ':' . $self->server_port . '/proxy');
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
            PeerAddr => $self->server_addr,
            PeerPort => $self->server_port,
        );
        select(undef, undef, undef, 0.5);
    }

    return defined $sock;
}

1;
