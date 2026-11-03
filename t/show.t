#!/usr/bin/perl
# scripts/vplane-show-portmonitor.pl with stub Vyatta::Config and
# Vyatta::Dataplane, and a copy whose rules command is a stub.
#
# SPDX-License-Identifier: GPL-2.0-only

use strict;
use warnings;
use File::Temp qw(tempdir);
use FindBin;
use Test::More tests => 5;

my $tmp = tempdir( CLEANUP => 1 );
open my $in, '<', "$FindBin::Bin/../scripts/vplane-show-portmonitor.pl" or BAIL_OUT("script: $!");
my $script = do { local $/ = undef; <$in> };
close $in or BAIL_OUT("script: $!");
$script =~ s{/opt/vyatta/sbin/vyatta-dp-npf-show-rules}{$tmp/show-rules}x
  or BAIL_OUT('no rules command');
open my $out, '>', "$tmp/show.pl" or BAIL_OUT("copy: $!");
print {$out} $script;
close $out or BAIL_OUT("copy: $!");
open my $rules, '>', "$tmp/show-rules" or BAIL_OUT("stub: $!");
print {$rules} "#!/bin/sh\nprintf 'rules'; printf '|%s' \"\$@\"; echo\n";
close $rules or BAIL_OUT("stub: $!");
chmod oct 755, "$tmp/show-rules";

local $ENV{STUB_ORIG} =
    '{"service":{"portmonitor":{"session":{'
  . '"1":{"description":"uplink copy","source":{"dp0s3":{},"dp0s4":{}}},'
  . '"2":{"source":{"dp0s6":{}}}}}}}';

sub show {
    my (@args) = @_;
    my $pid    = open my $fh, '-|';
    defined $pid or BAIL_OUT("fork: $!");
    if ( !$pid ) {
        open STDERR, '>&', \*STDOUT or exit 126;
        exec $^X, "-I$FindBin::Bin/lib", "$tmp/show.pl", @args or exit 127;
    }
    my $text = do { local $/ = undef; <$fh> }
      // q{};
    close $fh;
    return $text;
}

local $ENV{STUB_SHOW} = <<'END';
{"portmonitor_information":[
 {"session":1,"type":"span","state":"enabled",
  "source_interfaces":[{"name":"dp0s3","direction":"both","rx_vlan":[10,20],"tx_vlan":[]},
                       {"name":"dp0s4","direction":"rx"}],
  "destination_interface":"dp0s5",
  "filters":[{"name":"f1","type":"in"}]},
 {"session":2,"type":"erspan-destination","state":"disabled","erspanid":7,"erspanhdr":1,
  "source_interfaces":[{"name":"tun0","direction":"both"}]}]}
END
my $fmt = "  %-28s %s\n";
is(
    show('--show'),
    "[dataplane: portmonitor show session]\n"
      . sprintf( $fmt, 'Session: ',                 1 )
      . sprintf( $fmt, '  Type: ',                  'span' )
      . sprintf( $fmt, '  State: ',                 'enabled' )
      . sprintf( $fmt, '  Description: ',           'uplink copy' )
      . sprintf( $fmt, '  Source interfaces: ',     q{} )
      . sprintf( $fmt, '    Name: ',                'dp0s3' )
      . sprintf( $fmt, '      Direction: ',         'both' )
      . sprintf( $fmt, '      RX vlans: ',          '10,20' )
      . sprintf( $fmt, '    Name: ',                'dp0s4' )
      . sprintf( $fmt, '      Direction: ',         'rx' )
      . sprintf( $fmt, '  Destination interface: ', 'dp0s5' )
      . sprintf( $fmt, '  Filters: ',               q{} )
      . sprintf( $fmt, '    Name: ',                'f1' )
      . sprintf( $fmt, '      Type: ',              'in' )
      . sprintf( $fmt, 'Session: ',                 2 )
      . sprintf( $fmt, '  Type: ',                  'erspan-destination' )
      . sprintf( $fmt, '  State: ',                 'disabled' )
      . sprintf( $fmt, '  erspan Identifier: ',     7 )
      . sprintf( $fmt, '  erspan Header: ',         'type-II' )
      . sprintf( $fmt, '  Source interfaces: ',     q{} )
      . sprintf( $fmt, '    Name: ',                'tun0' ),
    'show: every session'
);

{
    local $ENV{STUB_SHOW} = '{"portmonitor_information":[]}';
    is(
        show( '--show', '--session=9' ),
        "[dataplane: portmonitor show session 9]\nPortmonitor: No session is configured\n",
        'show: none configured'
    );
}

is( show('--allowed'), "1\n2\n", 'allowed sessions' );
is(
    show( '--show-filter-info', '--session=1' ),
    "----------------------\nPortmonitor Session: 1\n----------------------\n"
      . "rules|interface:dp0s3|portmonitor-in|portmonitor-out\n"
      . "rules|interface:dp0s4|portmonitor-in|portmonitor-out\n",
    'filter info for a session'
);
is(
    show( '--show-srcif-filter-info', '--session=1', '--srcif=dp0s9' ),
    "Invalid source interface\n",
    'filter info for an unknown source'
);
