# NAME

Browsermob::Proxy - Perl client for the proxies created by the Browsermob server

[![Build Status](https://travis-ci.org/gempesaw/Browsermob-Proxy.svg?branch=master)](https://travis-ci.org/gempesaw/Browsermob-Proxy)

# VERSION

version 0.13

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

    my $proxy = Browsermob::Proxy->new(server_addr => '127.0.0.1');

## server\_port

Optional: Indicate at what port we should expect a Browsermob Server
to be running; defaults to 8080

    my $proxy = Browsermob::Proxy->new(server_port => 8080);

## port

Optional: When instantiating a proxy, you can choose the proxy port on
your own, or let the server automatically assign you an unused port.

    my $proxy = Browsermob::Proxy->new(port => 9091);

## trace

Set Net::HTTP::Spore's trace option; defaults to 0; set it to 1 to see
headers and 2 to see headers and responses. This can only be set during
construction; changing it afterwards will have no impact.

    my $proxy = Browsermob::Proxy->new( trace => 2 );

# METHODS

## new\_har

After creating a proxy, `new_har` creates a new HAR attached to the
proxy and returns the HAR content if there was a previous one. If no
argument is passed, the initial page ref will be "Page 1"; you can
also pass a string to choose your own initial page ref.

    $proxy->new_har;
    $proxy->new_har('Google');

This convenience method is just a helper around the actual endpoint
method `/create_new_har`; it uses the defaults of not capturing
headers, request/response bodies, or binary content. If you'd like to
capture those items, you can use `create_new_har` as follows:

    $proxy->create_new_har(
        payload => {
            initialPageRef => 'payload is optional'
        },
        captureHeaders => 'true',
        captureContent => 'true',
        captureBinaryContent => 'true'
    );

## har

After creating a proxy and initiating a [new\_har](https://metacpan.org/pod/new_har), you can retrieve
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

## firefox\_proxy

Generate a hash with the proper keys and values that for use in
setting preferences for a
[Selenium::Remote::Driver::Firefox::Profile](https://metacpan.org/pod/Selenium::Remote::Driver::Firefox::Profile). This method returns a
hashref; dereference it when you pass it to
["set\_preference" in Selenium::Remote::Driver::Firefox::Profile](https://metacpan.org/pod/Selenium::Remote::Driver::Firefox::Profile#set_preference):

    my $profile = Selenium::Remote::Driver::Firefox::Profile->new;

    my $firefox_pref = $proxy->firefox_proxy;
    $profile->set_preference( %{ $firefox_pref } );

    my $driver = Selenium::Remote::Driver->new_from_caps(
        desired_capabilities => {
            browserName => 'Firefox',
            firefox_profile => $profile->_encode
        }
    );

N.B.: `firefox_proxy` will AUTOMATICALLY call ["new\_har"](#new_har) for you
initiating an unnamed har, unless you pass it something truthy.

## ua\_proxy

Generate the proper arguments for the proxy method of
[LWP::UserAgent](https://metacpan.org/pod/LWP::UserAgent). By default, `ua_proxy` will initiate a new har for
you automatically, the same as ["selenium\_proxy"](#selenium_proxy) does. If you want to
initialize the har yourself, pass in something truthy.

    my $proxy = Browsermob::Proxy->new;
    my $ua = LWP::UserAgent->new;
    $ua->proxy($proxy->ua_proxy);

## set\_env\_proxy

Export to `%ENV` the properties of this proxy's port. This can be
used in tandem with <LWP::UserAgent/env\_proxy>. This will set the
appropriate environment variables, and then your `$ua` will pick it
up when its `env_proxy` method is invoked aftewards. As usual, this
will create a new HAR unless you deliberately inhibit it.

    $proxy->set_env_proxy;
    $ua->env_proxy;

In particular, we set `http_proxy`, `https_proxy`, and `ssl_proxy`
to the appropriate server and port by defining them as keys in `%ENV`.

## add\_basic\_auth

Set up automatic Basic authentication for a specified domain. Accepts
as input a HASHREF with the keys `domain`, `username`, and
`password`. For example,

    $proxy->add_basic_auth({
        domain => '.google.com',
        username => 'username',
        password => 'password'
    });

## set\_request\_header ( $header, $value )

Takes two STRINGs as arguments. (Unhelpfully) returns a
Net::HTTP::Spore::Response. With this method, we will remove the
specified `$header` from every request the proxy sees, and replace it
with the `$header` `$value` pair that you pass in.

    $proxy->set_request_header( 'User-Agent', 'superwoman' );

Under the covers, we are using ["filter\_request"](#filter_request) with a Javascript
Rhino payload.

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

# COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Daniel Gempesaw.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
