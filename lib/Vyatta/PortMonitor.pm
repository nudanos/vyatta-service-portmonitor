# Module: PortMonitor.pm
# Functions to get Portmonitor info needed by other modules
#
# Copyright (c) 2020 AT&T Intellectual Property.
#    All Rights Reserved.
#
# SPDX-License-Identifier: LGPL-2.1-only

package Vyatta::PortMonitor;
use strict;
use warnings;
use Vyatta::Config;
use parent qw(Exporter);

our @EXPORT_OK = qw(get_portmonitor_destination_intflist);

#
# Get all the interfaces that are configured as destination for
# all portmonitor sessions
#
sub get_portmonitor_destination_intflist {
    my $config = Vyatta::Config->new("service portmonitor session");
    return map { $config->returnValues("$_ destination") } $config->listNodes();
}

1;
