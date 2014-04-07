# NAME

Browsermob::Proxy - Perl client for the proxies created by the Browsermob server

# VERSION

version 0.01

# SYNOPSIS

    my $proxy = Browsermob::Proxy->new(
        server_port => 9090
        # port => 9092
    );

    print $proxy->port;
    $proxy->new_har('Google');
    # create network traffic across your port
    $proxy->har; # returns a HAR as a JSON blob

# DESCRIPTION

An instance of a Browsermob proxy that you can use to capture HARs,
filter traffic, limit network speeds, etc. This can be used completely
independently of [Browsermob::Server](https://metacpan.org/pod/Browsermob::Server) if you want to manage the
server separately.

If you are manually instantiating instances of this class, you must
specify the `server_port` so we know where to find the
browsermob-proxy server.

# ATTRIBUTES

## port

Optional: When instantiating a proxy, you can choose the proxy port on
your own, or let it automatically assign you a port for the proxy.

# METHODS

## get\_ports

Get a list of ports attached to a ProxyServer managed by ProxyManager

    $proxy->get_proxies

## create

Create a new proxy. This method is automatically invoked upon
instantiation, so you shouldn't have to call it unless you're doing
something unexpected.

## delete\_proxy

Shutdown the proxy and close the port. This is automatically invoked
when the `$proxy` goes out of scope, so you shouldn't have to call
this either.

    $proxy->delete_proxy;

## new\_har

## new

Instantiate a new proxy. `server_port` is a required argument; if
you're using `BrowserMob::Server`, just invoke that class's
`create_proxy` method.

    my $proxy = $bmp->create_proxy; # invokes new for you

    my $proxy = BrowserMob::Proxy->new(server_port => 63638);

# BUGS

Please report any bugs or feature requests on the bugtracker website
https://github.com/gempesaw/Browsermob-Proxy/issues

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

# AUTHOR

Daniel Gempesaw <gempesaw@gmail.com>
