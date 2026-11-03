#!/usr/bin/perl
# Vyatta::PortMonitor::get_portmonitor_destination_intflist, loaded on its
# own (as vyatta-bonding and the interface scripts do), with a stub
# Vyatta::Config.
#
# SPDX-License-Identifier: GPL-2.0-only

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib";
use Test::More tests => 1;

use Vyatta::PortMonitor qw(get_portmonitor_destination_intflist);

local $ENV{STUB_CONFIG} =
    '{"service":{"portmonitor":{"session":{'
  . '"1":{"destination":["dp0s5"]},"2":{"destination":["dp0s6","dp0s7"]},'
  . '"3":{}}}}}';
is_deeply( [ get_portmonitor_destination_intflist() ],
    [qw(dp0s5 dp0s6 dp0s7)], 'destinations of every session' );
