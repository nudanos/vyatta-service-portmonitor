#!/usr/bin/perl
# Tests for scripts/vplane-portmonitor-validate.pl, the portmonitor commit
# checks, with stub Vyatta::Config/Interface/SwitchConfig/Platform.
#
# SPDX-License-Identifier: GPL-2.0-only

use strict;
use warnings;
use FindBin;
use JSON::PP;
use Test::More tests => 18;

my $json = JSON::PP->new->canonical;

sub validate {
    my ( $config, %env ) = @_;
    local $ENV{STUB_CONFIG} = $json->encode($config);
    local $ENV{STUB_ORIG}   = $json->encode( delete $env{orig} // {} );
    local @ENV{ keys %env } = values %env;
    my $pid = open my $out, '-|';
    defined $pid or BAIL_OUT("fork: $!");
    if ( !$pid ) {
        open STDERR, '>&', \*STDOUT or exit 126;
        exec $^X, "-I$FindBin::Bin/lib", "$FindBin::Bin/../scripts/vplane-portmonitor-validate.pl"
          or exit 127;
    }
    my $text = do { local $/ = undef; <$out> }
      // q{};
    close $out;
    return ( $? >> 8, $text );
}

my %dataplane =
  ( dataplane => { dp0s3 => { vif => { 10 => {} } }, dp0s4 => {}, dp0s5 => {}, dp0s6 => {} } );

sub span {
    my (%sessions) = @_;
    return { service => { portmonitor => { session => \%sessions } }, interfaces => \%dataplane };
}

my ( $rc, $out ) = validate(
    span(
        1 => {
            type        => 'span',
            source      => { dp0s3 => { direction => 'rx' } },
            destination => ['dp0s5']
        }
    )
);
is( $rc, 0, 'span session: valid' ) or diag $out;

( $rc, $out ) = validate(
    span(
        1 => {
            type        => 'span',
            source      => { dp0s3 => { direction => 'rx' }, dp0s4 => { direction => 'rx' } },
            destination => ['dp0s5']
        }
    ),
    STUB_HW_INTERFACES => 'dp0s3 dp0s4',
    STUB_LIMITS        => '{"hw_rx_src_count":16,"hw_rx_sess_count":16,"hw_sess_count":16}'
);
is( $rc, 0, 'two hardware sources within a limit of 16: valid' ) or diag $out;

( $rc, $out ) = validate(
    span(
        1 => {
            type        => 'span',
            source      => { dp0s3 => { direction => 'rx' }, dp0s4 => { direction => 'rx' } },
            destination => ['dp0s5']
        }
    ),
    STUB_HW_INTERFACES => 'dp0s3 dp0s4',
    STUB_LIMITS        => '{"hw_rx_src_count":1,"hw_rx_sess_count":4,"hw_sess_count":4}'
);
isnt( $rc, 0, 'two hardware sources over a limit of 1: refused' );
like( $out, qr{max[ ]hw-rx[ ]interface[ ]limit[ ]1}x, 'hardware limit reported' );

( $rc, $out ) = validate(
    span( 1 => { type => 'span', source => { 'dp0s3.10' => {} }, destination => ['dp0s5'] } ) );
is( $rc, 0, 'vif source: valid' ) or diag $out;

( $rc, $out ) = validate(
    span( 1 => { type => 'span', source => { 'dp0s3.20' => {} }, destination => ['dp0s5'] } ) );
like( $out, qr{Invalid[ ]vif[ ]20}x, 'unknown vif refused' );

( $rc, $out ) = validate(
    span(
        1 => { type => 'span', source => { dp0s3 => {} }, destination => ['dp0s5'] },
        2 => { type => 'span', source => { dp0s3 => {} }, destination => ['dp0s6'] }
    )
);
ok( index( $out, 'dp0s3 for session 2 is already configured as source' ) >= 0,
    'a source in two sessions refused' );

( $rc, $out ) = validate( span( 1 => { source => { dp0s3 => {} } } ) );
like( $out, qr{does[ ]not[ ]have[ ]type}x, 'session without a type refused' );

( $rc, $out ) = validate(
    span( 1 => { type => 'rspan-source', source => { dp0s3 => {} }, destination => ['dp0s5'] } ),
    orig => { service => { portmonitor => { session => { 1 => { type => 'span' } } } } }
);
like( $out, qr{Changing[ ]the[ ]type}x, 'changing the type refused' );

( $rc, $out ) = validate(
    span(
        1 => {
            type        => 'span',
            source      => { dp0s3 => {} },
            destination => ['dp0s5'],
            filter      => { in => ['f1'] }
        }
    )
);
is( $rc, 0, 'filters on a span session: valid' ) or diag $out;

# destination checks: [ description, dataplane config of dp0s5, error ]
my @destination_cases = (
    [ 'disabled', { disable => {} }, qr{dp0s5[ ]for[ ]portmonitor[ ]is[ ]disabled}x ],
    [
        'bridge port',
        { 'bridge-group' => { bridge => 'br0' } },
        qr{cannot[ ]be[ ]part[ ]of[ ]bridge-group}x
    ],
    [ 'address', { address => ['192.0.2.1/24'] }, qr{cannot[ ]have[ ]address}x ],
    [
        'ip attribute',
        { ip => { 'rpf-check' => 'strict' } },
        qr{cannot[ ]have[ ]any[ ]ip[ ]attributes}x
    ],
);
foreach my $case (@destination_cases) {
    my ( $what, $dp0s5, $error ) = @{$case};
    local $dataplane{dataplane}{dp0s5} = $dp0s5;
    ( $rc, $out ) = validate(
        span( 1 => { type => 'span', source => { dp0s3 => {} }, destination => ['dp0s5'] } ) );
    like( $out, $error, "destination $what: refused" );
}

{
    local $dataplane{dataplane}{dp0s5} = { vif => { 7 => { address => ['192.0.2.1/24'] } } };
    ( $rc, $out ) = validate(
        span(
            1 => { type => 'rspan-source', source => { dp0s3 => {} }, destination => ['dp0s5.7'] }
        )
    );
    like(
        $out,
        qr{dp0s5[.]7[ ]for[ ]portmonitor[ ]cannot[ ]have[ ]address}x,
        'rspan destination vif with an address: refused'
    );

    $dataplane{dataplane}{dp0s5} = { vif => { 7 => {} } };
    ( $rc, $out ) = validate(
        span(
            1 => { type => 'rspan-source', source => { dp0s3 => {} }, destination => ['dp0s5.7'] }
        )
    );
    is( $rc, 0, 'rspan destination vif: valid' ) or diag $out;
}

( $rc, $out ) = validate(
    span( 1 => { type => 'span', source => { dp0s3 => {} }, destination => ['dp0s5.7'] } ) );
like( $out, qr{needs[ ]to[ ]be[ ]physical}x, 'span destination vif: refused' );

( $rc, $out ) =
  validate( span( 1 => { type => 'span', source => { dp0s3 => {} }, destination => ['dp0s5'] } ),
    STUB_HW_INTERFACES => 'dp0s5' );
like(
    $out,
    qr{Hardware-switched[ ]destination}x,
    'hardware destination without hardware-only support: refused'
);
