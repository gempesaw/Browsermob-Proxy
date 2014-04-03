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

    $proxy->create_har('Test');
    $proxy->har; # returns a HAR

=cut

=head1 DESCRIPTION

Browsermob Proxy allows us to create proxies to generate HARs from
network traffic. It's especially useful in tandem with Webdriver.

=cut

=attr path

Required. The path to the browsermob_proxy binary.

=cut

has path => (
    is => 'rw',
    required => 1
);

=attr port

The port on which the proxy server should run. This is not the port on
which you should have other clients connect to.

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

Start a browsermob proxy on port. Starting the server does not create
any proxies yet.

    my $bmp = Browsermob::Server->new;
    $bmp->start;

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

Stop the forked browsermob-proxy server.

    my $bmp = Browsermob::Server->new;
    $bmp->stop;

=cut

sub stop {
    my $self = shift;
    kill('SIGKILL', $self->_pid) and waitpid($self->_pid, 0);
}

=method create_proxy

After starting the server, or connecting to an existing one, use
`create_proxy` to get a proxy that you can use with your tests. No
proxies actually exist until you call create_proxy; starting the
server does not create a proxy.

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
