package Browsermob::Proxy::CompareParams;

# ABSTRACT: Look for a request with the specified matching request params
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(cmp_request_params);

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

=method cmp_request_params ( $har, $expected_params )

Pass in a $har object genereated by L</Browsermob::Proxy>, as well as
a hashref of key/value pairs of the request params that you want to
find. This method will return true if a request can be found with all
of the expected_params key/value pairs.

=cut

sub cmp_request_params {
    my ($got, $expected) = @_;
    my $got_hash = convert_har_params_to_hash($got);

    my @matched = grep {
        my $actual_params = $_;

        # The @missing array will contain the expected keys that
        # either do not exist in actual params, or they do exist but
        # the values aren't the same.
        my @missing = grep {
            ! ( exists $actual_params->{$_} and $actual_params->{$_} eq $expected->{$_} )
        } keys %{ $expected };

        # @missing should be empty for a successful request/assert
        # match.
        ! ( scalar @missing )
    } @{ $got_hash };

    return scalar @matched;
}

=method convert_har_params_to_hash

This isn't exported at all; we wouldn't expect that you'd need to use
it. But, if you're interested: the har format is a bit unwieldy to
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

=cut

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
