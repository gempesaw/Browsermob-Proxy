# NAME

Browsermob::Proxy - Perl client for the proxies created by the Browsermob server

# VERSION

version 0.01

# SYNOPSIS

Standalone:

    my $proxy = Browsermob::Proxy->new(
        server_port => 9090
        # port => 9092
    );

    print $proxy->port;
    $proxy->new_har('Google');
    # create network traffic across your port
    $proxy->har; # returns a HAR as a JSON blob

with [Browsermob::Server](https://metacpan.org/pod/Browsermob::Server):

    my $server = Browsermob::Server->new(
        server_port = 9090
    );
    $server->start; # ignore if your server is already running

    my $proxy = $server->create_proxy;
    $proxy->new_har('proxy from server!');

# DESCRIPTION

From [http://bmp.lightbody.net/](http://bmp.lightbody.net/): BrowserMob proxy is based on
technology developed in the Selenium open source project and a
commercial load testing and monitoring service originally called
BrowserMob and now part of Neustar.

It can capture performance data for web apps (via the HAR format), as
well as manipulate browser behavior and traffic, such as whitelisting
and blacklisting content, simulating network traffic and latency, and
rewriting HTTP requests and responses.

This module is a Perl client interface to interact with the server and
its proxies. It uses [Net::HTTP::Spore](https://metacpan.org/pod/Net::HTTP::Spore). You can use
[Browsermob::Server](https://metacpan.org/pod/Browsermob::Server) to manage the server itself in addition to using
this module to handle the proxies.

# ATTRIBUTES

## server\_port

Required. Indicate at what localhost port we should expect a
Browsermob Server to be running.

## port

Optional: When instantiating a proxy, you can choose the proxy port on
your own, or let it automatically assign you a port for the proxy.

# METHODS

## get\_ports

Get a list of ports attached to a ProxyServer managed by ProxyManager

    $proxy->get_proxies

## new

Instantiate a new proxy. `server_port` is the only required argument
if you're instantiating this class manually.

    my $proxy = $bmp->create_proxy; # invokes new for you

    my $proxy = BrowserMob::Proxy->new(server_port => 63638);

## new\_har

After creating a proxy, `new_har` creates a new HAR attached to the
proxy and returns the HAR content if there was a previous one. If no
argument is passed, the initial page ref will be "Page 1"; you can
also pass a string to choose your own initial page ref.

    $proxy->new_har;
    $proxy->new_har('Google');

## create

Create a new proxy. This method is automatically invoked upon
instantiation, so you shouldn't have to call it unless you're doing
something unexpected. In fact, if you do call it, things will probably
get messed up.

## delete\_proxy

Shutdown the proxy and close the port. This is automatically invoked
when the `$proxy` goes out of scope, so you shouldn't have to call
this either. In fact, if you do call it, things will probably
get messed up.

# SEE ALSO

Please see those modules/websites for more information related to this module.

- [http://bmp.lightbody.net/](http://bmp.lightbody.net/)
- [https://github.com/lightbody/browsermob-proxy](https://github.com/lightbody/browsermob-proxy)
- [Browsermob::Server](https://metacpan.org/pod/Browsermob::Server)

# BUGS

Please report any bugs or feature requests on the bugtracker website
https://github.com/gempesaw/Browsermob-Proxy/issues

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

# AUTHOR

Daniel Gempesaw <gempesaw@gmail.com>
