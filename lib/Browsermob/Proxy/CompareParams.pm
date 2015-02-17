package Browsermob::Proxy::CompareParams;
$Browsermob::Proxy::CompareParams::VERSION = '0.10';
# ABSTRACT: Look for a request with the specified matching request params
require Exporter;
our @ISA = qw/Exporter/;
our @EXPORT = qw/cmp_request_params/;
our @EXPORT_OK = qw/convert_har_params_to_hash/;



sub cmp_request_params {
    my ($got, $expected) = @_;
    my $got_hash = convert_har_params_to_hash($got);

    # Start by assuming that we can't find any of our expected keys
    my @least_missing = keys %{ $expected };

    my @matched = grep {
        my $actual_params = $_;

        # The @missing array will contain the expected keys that
        # either do not exist in actual params, or they do exist but
        # the values aren't the same.
        my @missing = grep {
            ! ( exists $actual_params->{$_} and $actual_params->{$_} eq $expected->{$_} )
        } keys %{ $expected };

        if (scalar @missing < scalar @least_missing) {
            @least_missing = @missing;
        }

        # @missing will be empty for a successful request/assert
        # match.
        ! ( scalar @missing )
    } @{ $got_hash };

    if (wantarray) {
        # In list context, provide the closest match for context on
        # the caller's side
        my $missing = { map {
            $_ => $expected->{$_}
        } @least_missing };
        return (scalar @matched, $missing);
    }
    else {
        return scalar @matched;
    }
}


sub convert_har_params_to_hash {
    my ($har_or_requests) = @_;

    my $requests;
    if (ref($har_or_requests) eq 'HASH' && exists $har_or_requests->{log}->{entries}) {
        $requests = $har_or_requests->{log}->{entries};
    }
    else {
        $requests = $har_or_requests;
    }

    my $hash = [
        map {
            my $params = $_->{request}->{queryString};
            my $pairs = { map {
                $_->{name} => $_->{value}
            } @$params };

            $pairs
        } @{ $requests }
    ];

    return $hash;

}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Browsermob::Proxy::CompareParams - Look for a request with the specified matching request params

=head1 VERSION

version 0.10

=head1 SYNOPSIS

    # create a har with traffic
    my $ua = LWP::UserAgent->new;
    my $proxy = Browsermob::Server->new->create_proxy;
    $ua->proxy($proxy->ua_proxy);
    $ua->get('http://www.perl.org/?query=string');
    my $har = $proxy->har;

    # ask the har if any requests have the following query params
    my $request_found = cmp_request_params($har, { query => 'string' });
    if ($request_found) {
        print 'A request was found with ?query=string in it';
    }

=head1 DESCRIPTION

Our primary use of Browsermob::Proxy is for checking analytics
requests. They're transferred primarily in the form of request
parameters, so it behooves us to make it easy to check if our HAR has
any requests that match a set of our expected request params.

By default, we only export the one function: L</cmp_request_params>.

=head1 METHODS

=head2 cmp_request_params ( $har, $expected_params )

Pass in a $har object genereated by L</Browsermob::Proxy>, as well as
a hashref of key/value pairs of the request params that you want to
find. In scalar context, this method will return the number of
requests that can be found with all of the expected_params key/value
pairs. If no requests are found, it returns that number: 0. So, the
scalar context returns a boolean if we were able to find any matching
requests.

    # look for a request matching ?expected=params&go=here
    my $bool = cmp_request_params($har, { expected => 'params', go => 'here' });
    say 'We found it!' if $bool;

In list context, the sub will return the boolean status as before, as
well as a hashref with the missing pieces from the closest request.

    my ($bool, $missing_params) = cmp_request_params($har, $expected);
    if ( ! $bool ) {
        say 'We are missing: ';
        print Dumper $missing_params;
    }

=head2 convert_har_params_to_hash

This isn't exported by default; we wouldn't expect that you'd need to
use it. But, if you're interested: the har format is a bit unwieldy to
work with. The requests come in an array of objects. Each object in
the array is a hash with a request key which points to an object with
a queryString key. The queryString object is an array of hashes with
name and value keys, the values of which are the actual query
params. Here's an example of one request:

    [0] {
        ...
        request           {
            ...
            queryString   [
                [0] {
                    name    "query",
                    value   "string"
                },
                [1] {
                    name    "query2",
                    value   "string2"
                },
            ],
            url           "http://127.0.0.1/b/ss?query=string&query2=string2"
        },
        ...
    }

This function would transform that request into an array of hash
objects where the keys are the param names and the values are the
param values:

    \ [
        [0] {
            query   "string"
            query2   "string2"
        }
    ]

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<Browsermob::Proxy|Browsermob::Proxy>

=back

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
https://github.com/gempesaw/Browsermob-Proxy/issues

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

Daniel Gempesaw <gempesaw@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Daniel Gempesaw.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
