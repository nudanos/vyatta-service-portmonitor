#!/usr/bin/perl
# scripts/vyatta-portmonitor.pl --action=update: the dataplane commands for
# a commit, from stub Vyatta::Config trees (candidate and running) through
# a stub Vyatta::VPlaned.
#
# SPDX-License-Identifier: GPL-2.0-only

use strict;
use warnings;
use FindBin;
use JSON::PP;
use Test::More tests => 3;

my $json = JSON::PP->new->canonical;

# Runs @cmd and returns its combined output.
sub capture {
    my @cmd = @_;
    my $pid = open my $out, '-|';
    defined $pid or BAIL_OUT("fork: $!");
    if ( !$pid ) { open STDERR, '>&', \*STDOUT or exit 126; exec @cmd or exit 127; }
    my $text = do { local $/ = undef; <$out> }
      // q{};
    close $out;
    return $text;
}

sub commit {
    my ( $new, $orig ) = @_;
    local $ENV{STUB_CONFIG} =
      $json->encode( { service => { portmonitor => { session => $new } } } );
    local $ENV{STUB_ORIG} =
      $json->encode( { service => { portmonitor => { session => $orig } } } );
    return capture( $^X, "-I$FindBin::Bin/lib", "$FindBin::Bin/../scripts/vyatta-portmonitor.pl",
        '--action=update' );
}

my $k        = 'service portmonitor session';
my %session1 = (
    type        => 'span',
    source      => { 'dp0s3' => { direction => 'rx' }, 'dp0s4.10' => { direction => 'both' } },
    destination => ['dp0s5'],
    filter      => { in => ['f1'] },
);

is( commit( { 1 => \%session1 }, {} ), <<"END", 'new session' );
SET $k 1 type => portmonitor set session 1 type 1 0 0 [undef]
SET $k 1 filter in f1 => portmonitor set session 1 filter-in f1 0 0 [undef]
SET $k 1 source dp0s3 => portmonitor set session 1 srcif dp0s3 0 1 [dp0s3]
SET $k 1 __pmf_attach dp0s3 in f1 => npf-cfg attach interface:dp0s3 portmonitor-in fw:f1 [dp0s3]
SET $k 1 source dp0s4.10 => portmonitor set session 1 srcif dp0s4 10 0 [dp0s4]
SET $k 1 __pmf_attach dp0s4.10 in f1 => npf-cfg attach interface:dp0s4.10 portmonitor-in fw:f1 [dp0s4.10]
SET $k 1 destination => portmonitor set session 1 dstif dp0s5 0 0 [dp0s5]
SET npf-cfg commit => npf-cfg commit [undef]
END

is(
    commit( { 1 => { %session1, destination => ['dp0s6'], disable => {} } }, { 1 => \%session1 } ),
    <<"END", 'changed session'
SET $k 1 disable => portmonitor set session 1 disable 0 0 0 [undef]
DELETE $k 1 destination => portmonitor del session 1 dstif dp0s5 0 0 [dp0s5]
SET $k 1 destination => portmonitor set session 1 dstif dp0s6 0 0 [dp0s6]
END
);

is( commit( {}, { 1 => \%session1 } ), <<"END", 'deleted session' );
DELETE $k 1 __pmf_attach dp0s3 in f1 => npf-cfg detach interface:dp0s3 portmonitor-in fw:f1 [dp0s3]
DELETE $k 1 __pmf_attach dp0s4.10 in f1 => npf-cfg detach interface:dp0s4.10 portmonitor-in fw:f1 [dp0s4.10]
DELETE $k 1  => portmonitor del session 1 0 0 0 0 [undef]
SET npf-cfg commit => npf-cfg commit [undef]
END
