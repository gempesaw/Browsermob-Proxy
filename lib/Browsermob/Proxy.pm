package Browsermob::Proxy;

# ABSTRACT: Perl client for the proxies created by the Browsermob server
use Moo;
use JSON;
use Net::HTTP::Spore;

=head1 SYNOPSIS

    my $proxy = Browsermob::Proxy->new(
        server_port => 9090
        port => 9092          # optional
    );

    print $proxy->port;
    $proxy->new_har('Google');
    # create network traffic across your port
    $proxy->har; # returns a HAR as a JSON blob

=head1 DESCRIPTION

An instance of a Browsermob proxy that you can use to capture HARs,
filter traffic, limit network speeds, etc.

=cut

my $spec = {
    name => 'BrowserMob Proxy',
    formats => ['json'],
    version => '0.01',
    methods => {
        get_ports => {
            path => '/',
            method => 'GET',
            description => 'Get a list of ports attached to ProxyServer instances managed by ProxyManager'
        },
        create_proxy => {
            path => '/',
            method => 'POST',
            description => 'Create a new proxy. Returns a JSON object {"port": your_port} on success"'
        },
        delete_proxy => {
            path => '/:port',
            method => 'DELETE',
            required_params => [
                'port'
            ],
            description => 'Shutdown the proxy and close the port'
        }
    }
};

=method new

Instantiate a new proxy. server_port is a required option in the args
hash. You can either do this on your own, or use
L<Browsermob::Server>'s create_proxy method.

=attr server_port

Required. Port at which the browsermob proxy server is running. This
is not the same as the proxy port.

=cut

has server_port => (
    is => 'ro',
    required => 1
);

=attr port

Optional: When instantiating a ::Proxy, you can choose the port on
your own, or let it automatically assign you a port for the proxy.

=cut

has port => (
    is => 'rw',
    lazy => 1,
    default => sub { '' }
);

has _spore => (
    is => 'ro',
    lazy => 1,
    builder => sub {
        my $self = shift;
        my $client = Net::HTTP::Spore->new_from_string(
            to_json($self->_spec),
            # trace => 2
        );
        $client->enable('Format::JSON');
        return $client;
    },
    handles => [keys $spec->{methods}]
);

has _spec => (
    is => 'ro',
    lazy => 1,
    builder => sub {
        my $self = shift;
        $spec->{base_url} = 'http://localhost:' . $self->server_port . '/proxy';
        return $spec;
    }
);

sub BUILD{
    my ($self, $args) = @_;

    $self->port($self->create_proxy->body->{port});
}

sub DESTROY{
    my $self = shift;
    $self->delete_proxy(port => $self->port);
}

1;
