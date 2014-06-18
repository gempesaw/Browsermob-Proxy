# NAME

Browsermob::Proxy - Perl client for the proxies created by the Browsermob server

[![Build Status](https://travis-ci.org/gempesaw/Browsermob-Proxy.svg?branch=master)](https://travis-ci.org/gempesaw/Browsermob-Proxy)

# VERSION

version 0.07

# SYNOPSIS

Standalone:

    my $proxy = Browsermob::Proxy->new(
        server_port => 9090
        # port => 9092
    );

    print $proxy->port;
    $proxy->new_har('Google');
    # create network traffic across your port
    $proxy->har; # returns a HAR as a hashref, converted from JSON

with [Browsermob::Server](https://metacpan.org/pod/Browsermob::Server):

    my $server = Browsermob::Server->new(
        server_port => 9090
    );
    $server->start; # ignore if your server is already running

    my $proxy = $server->create_proxy;
    $proxy->new_har('proxy from server!');

# DESCRIPTION

From [http://bmp.lightbody.net/](http://bmp.lightbody.net/):

> BrowserMob proxy is based on technology developed in the Selenium open
> source project and a commercial load testing and monitoring service
> originally called BrowserMob and now part of Neustar.
>
> It can capture performance data for web apps (via the HAR format), as
> well as manipulate browser behavior and traffic, such as whitelisting
> and blacklisting content, simulating network traffic and latency, and
> rewriting HTTP requests and responses.

This module is a Perl client interface to interact with the server and
its proxies. It uses [Net::HTTP::Spore](https://metacpan.org/pod/Net::HTTP::Spore). You can use
[Browsermob::Server](https://metacpan.org/pod/Browsermob::Server) to manage the server itself in addition to using
this module to handle the proxies.

# ATTRIBUTES

## server\_addr

Optional: specify where the proxy server is; defaults to 127.0.0.1

## server\_port

Optional: Indicate at what port we should expect a Browsermob Server
to be running; defaults to 8080

    my $proxy = Browsermob::Proxy->new(server_port => 8080);

## port

Optional: When instantiating a proxy, you can choose the proxy port on
your own, or let it automatically assign you a port for the proxy.

    my $proxy = Browsermob::Proxy->new(
        server_port => 8080
        port => 9091
    );

## trace

Set Net::HTTP::Spore's trace option; defaults to 0; set it to 1 to see
headers and 2 to see headers and responses. This can only be set during
construction.

    my $proxy = Browsermob::Proxy->new( trace => 2 );

# METHODS

## new\_har

After creating a proxy, `new_har` creates a new HAR attached to the
proxy and returns the HAR content if there was a previous one. If no
argument is passed, the initial page ref will be "Page 1"; you can
also pass a string to choose your own initial page ref.

    $proxy->new_har;
    $proxy->new_har('Google');

## har

After creating a proxy and initiating a `new_har`, you can retrieve
the contents of the current HAR with this method. It returns a hashref
HAR, and may in the future return an isntance of [Archive::HAR](https://metacpan.org/pod/Archive::HAR).

    my $har = $proxy->har;
    print Dumper $har->{log}->{entries}->[0];

## selenium\_proxy

Generate the proper capabilities for use in the constructor of a new
Selenium::Remote::Driver object.

    my $proxy = Browsermob::Proxy->new;
    my $driver = Selenium::Remote::Driver->new(
        browser_name => 'chrome',
        proxy        => $proxy->selenium_proxy
    );
    $driver->get('http://www.google.com');
    print Dumper $proxy->har;

N.B.: `selenium_proxy` will AUTOMATICALLY call ["new\_har"](#new_har) for you
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

## ua\_proxy

Generate the proper arguments for the proxy method of
[LWP::UserAgent](https://metacpan.org/pod/LWP::UserAgent). By default, `ua_proxy` will initiate a new har for
you automatically, the same as ["selenium\_proxy"](#selenium_proxy) does. If you want to
initialize the har yourself, pass in something truthy.

    my $proxy = Browsermob::Proxy->new;
    my $ua = LWP::UserAgent->new;
    $ua->proxy($proxy->ua_proxy);

## add\_basic\_auth

Set up automatic Basic authentication for a specified domain. Accepts
as input a HASHREF with the keys `domain`, `username`, and
`password`. For example,

    $proxy->add_basic_auth({
        domain => '.google.com',
        username => 'username',
        password => 'password'
    });

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
