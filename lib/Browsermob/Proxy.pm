package Browsermob::Proxy;

# ABSTRACT: Perl client for the proxies created by the Browsermob server
use Moo;
use JSON;
use Net::HTTP::Spore;

=head1 SYNOPSIS

    my $proxy = Browsermob::Proxy->new(
        server_port => 9090
        # port => 9092
    );

    print $proxy->port;
    $proxy->new_har('Google');
    # create network traffic across your port
    $proxy->har; # returns a HAR as a JSON blob

=head1 DESCRIPTION

An instance of a Browsermob proxy that you can use to capture HARs,
filter traffic, limit network speeds, etc. This can be used completely
independently of L<Browsermob::Server> if you want to manage the
server separately.

If you are manually instantiating instances of this class, you must
specify the C<server_port> so we know where to find the
browsermob-proxy server.

=cut

=method get_ports

Get a list of ports attached to a ProxyServer managed by ProxyManager

    $proxy->get_proxies

=method create

Create a new proxy. This method is automatically invoked upon
instantiation, so you shouldn't have to call it unless you're doing
something unexpected.

=method delete_proxy

Shutdown the proxy and close the port. This is automatically invoked
when the C<$proxy> goes out of scope, so you shouldn't have to call
this either.

    $proxy->delete_proxy;

=method new_har



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

has server_port => (
    is => 'ro',
    required => 1
);

=attr port

Optional: When instantiating a proxy, you can choose the proxy port on
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

=method new

Instantiate a new proxy. C<server_port> is a required argument; if
you're using C<BrowserMob::Server>, just invoke that class's
C<create_proxy> method.

    my $proxy = $bmp->create_proxy; # invokes new for you

    my $proxy = BrowserMob::Proxy->new(server_port => 63638);

=cut

sub BUILD{
    my ($self, $args) = @_;

    eval {
        $self->port($self->create->body->{port});
    };
}

sub DESTROY{
    my $self = shift;
    $self->delete_proxy;
}

1;
