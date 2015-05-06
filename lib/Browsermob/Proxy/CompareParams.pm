package Browsermob::Proxy::CompareParams;

# ABSTRACT: Look for a request with the specified matching request params
use Carp qw/croak/;
use List::Util qw/none/;

require Exporter;
our @ISA = qw/Exporter/;
our @EXPORT = qw/cmp_request_params/;
our @EXPORT_OK = qw/convert_har_params_to_hash
                    replace_placeholder_values
                    collect_query_param_keys/;

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

=cut

=method cmp_request_params ( $har, $expected_params )

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

=cut

sub cmp_request_params {
    my ($got, $expected, $user_cmp) = @_;
    my $got_hash = convert_har_params_to_hash($got);
    my $compare = generate_comparison_sub($user_cmp);

    # We don't want to assert the presence of keys like "!missing"
    my ($expected_params, $expected_missing) = _split_expected_asserts( $expected );

    # Start by assuming that we can't find any of our expected keys
    my @least_missing = keys %{ $expected };

    my @matched = grep {
        my $actual_params = $_;

        # The @missing array will contain the expected keys that
        # either do not exist in actual params, or they do exist but
        # the values aren't the same.
        my @missing = grep {
            if ( exists $actual_params->{$_} ) {
                my ($got, $exp) = ($actual_params->{$_}, $expected_params->{$_});
                if ( $compare->( $got, $exp ) ) {
                    ''
                }
                else {
                    'missing'
                }
            }
            else {
                'missing'
            }
        } keys %{ $expected_params };

        # We need to keep track of the closest match we've found so
        # far so we can tell the caller about it when we're done
        if (scalar @missing < scalar @least_missing) {
            @least_missing = @missing;
        }

        # @missing will be empty for a successful request/assert
        # match.
        ! ( scalar @missing )
    } @{ $got_hash };

    # We need to filter our @matched requests to skip ones that have
    # keys that we expect to be missing.
    @matched = _grep_missing_asserts( \@matched, $expected_missing );

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

sub _split_expected_asserts {
    my ( $expected ) = @_;

    my ($present, $missing) = ( {}, {} );
    foreach my $key (keys %$expected) {
        if ($key =~ /^!/) {
            $missing->{$key} = $expected->{$key};
        }
        else {
            $present->{$key} = $expected->{$key};
        }
    }

    return ($present, $missing);
}

sub _grep_missing_asserts {
    my ( $got, $expected_missing ) = @_;

    my @missing_keys = map { s/^!//; $_ } keys %$expected_missing;

    my @matched = grep {
        my @got_keys = keys %$_;

        my $ret = 1;
        foreach my $expected_missing (@missing_keys) {
            $ret = $ret && none {
                $_ eq $expected_missing
            } @got_keys;
        }

        $ret;
    } @{ $got };

    return @matched;
}

=method convert_har_params_to_hash

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

sub generate_comparison_sub {
    my ($user_comparison) = @_;
    my $string_equality = sub { $_[0] eq $_[1] };

    if (! defined $user_comparison) {
        return $string_equality;
    }

    my $ref = ref($user_comparison);
    if ($ref ne 'CODE') {
        croak 'We expected your custom comparison to be a CODEREF, not a ' . $ref . '!';
    }

    return sub {
        my ($got, $expected) = @_;

        return $string_equality->($got, $expected) || $user_comparison->($got, $expected);
    };

}

=func replace_placeholder_values

Takes two arguments: a HAR or the C<->{log}->{entries}> of a HAR, and
an assert hashref. If the assert has a value that starts with a colon
C<:>, and that value exists as a key in any of the HAR's actual query
parameter pairs, we'll replace the asserted value with the matching
assert's key.

An example may help make this clear: say you assert the following
hashref

    $assert = {
        query => 'param',
        query2 => ':query'
    };

and your HAR records a request to a URL with the following params:
C</endpoint?query=param&query2=param>. We'll return you a new
C<$assert>:

    $assert = {
        query => 'param',
        query2 => 'param'
    };

=cut

sub replace_placeholder_values {
    my ($requests, $assert) = @_;

    my $mutated = { map {
        my ($key, $value) = ($_, $assert->{$_});
        if ($value !~ /^ *: */) {
            $key => $value
        }
        else {
            my $replacement_key = $value;
            $replacement_key =~ s/^ *: *//;

            my $actual_keys = collect_query_param_keys($requests);
            my $found_existing_key = scalar(
                grep { $_ eq $replacement_key } @{ $actual_keys }
            );
            if ($found_existing_key) {
                $key => $assert->{$replacement_key};
            }
            else {
                $key => $value
            }
        }

    } keys %{ $assert } };

    return $mutated;
}

=func collect_query_param_keys

Given a HAR, or a the entries array of a HAR, we'll return a list of
all of the keys that were used in any of the query parameters. So if
your HAR contains a call to C</endpoint?example1&example2> and another
call to C</endpoint?example2&example3>, we'll return C<[ qw/ example1
example2 example3 ]>.

=cut

sub collect_query_param_keys {
    my ($requests) = @_;

    my $kv_params = convert_har_params_to_hash($requests);

    my $keys = {};
    foreach my $param_pairs (@{ $kv_params }) {
        map { $keys->{$_}++ } keys %{ $param_pairs };
    }

    return [ sort keys %{ $keys } ];
}

1;
