#!/usr/bin/perl
#
# Copyright (c) 2019 AT&T Intellectual Property. All rights reserved.
# Copyright (c) 2014-2015 Brocade Communications Systems, Inc.
# All Rights Reserved.
#
# SPDX-License-Identifier: GPL-2.0-only
#

use strict;
use warnings;
use lib "/opt/vyatta/share/perl5/";

use Getopt::Long;
use Vyatta::Dataplane;
use Vyatta::Config;
use JSON qw( decode_json );

my %erspanhdrs = (
    '1' => 'type-II',
    '2' => 'type-III',
);

my $show_rules_cmd = "/opt/vyatta/sbin/vyatta-dp-npf-show-rules";

my (
    $allowed_sessions,      $fabric,                 $session,
    $show_sessions,         $allowed_srcifs,         $show_filter_info,
    $allowed_pmsess_srcifs, $show_srcif_filter_info, $srcif
);
GetOptions(
    'allowed'                => \$allowed_sessions,
    'fabric=s'               => \$fabric,
    'session=s'              => \$session,
    'show'                   => \$show_sessions,
    'allowed-srcifs'         => \$allowed_srcifs,
    'show-filter-info'       => \$show_filter_info,
    'allowed-pmsess-srcifs'  => \$allowed_pmsess_srcifs,
    'show-srcif-filter-info' => \$show_srcif_filter_info,
    'srcif=s'                => \$srcif,
);

my $pmconfig = Vyatta::Config->new('service portmonitor');
my $fmt      = "  %-28s %s\n";

allowed_portmonitor_sessions()                    if ($allowed_sessions);
show_portmonitor($session)                        if ($show_sessions);
allowed_srcifs()                                  if ($allowed_srcifs);
show_pmsess_filter_info($session)                 if ($show_filter_info);
allowed_pmsess_srcifs($session)                   if ($allowed_pmsess_srcifs);
show_pmsess_srcif_filter_info( $session, $srcif ) if ($show_srcif_filter_info);

sub allowed_srcifs {
    foreach my $sessionid ( $pmconfig->listOrigNodes("session") ) {
        foreach my $source ( $pmconfig->listOrigNodes("session $sessionid source") ) {
            print "$source\n";
        }
    }
    return;
}

sub allowed_pmsess_srcifs {
    my ($sessionid) = @_;
    foreach my $source ( $pmconfig->listOrigNodes("session $sessionid source") ) {
        print "$source\n";
    }
    return;
}

sub print_sessionid {
    my ($sid) = @_;
    print "----------------------\n";
    print "Portmonitor Session: $sid\n";
    print "----------------------\n";
    return;
}

sub print_filter_rules {
    my ($interface) = @_;
    open my $rules, '-|', $show_rules_cmd, "interface:$interface",
      'portmonitor-in', 'portmonitor-out'
      or die "Cannot run $show_rules_cmd: $!\n";
    print while <$rules>;
    close $rules;
    return;
}

sub show_pmsess_filter_info {
    my ($sessionid) = @_;
    print_sessionid($sessionid);
    foreach my $source ( $pmconfig->listOrigNodes("session $sessionid source") ) {
        print_filter_rules($source);
    }
    return;
}

sub show_pmsess_srcif_filter_info {
    my ( $sessionid, $source ) = @_;
    if ( $pmconfig->existsOrig("session $sessionid source $source") ) {
        print_sessionid($sessionid);
        print_filter_rules($source);
    }
    else {
        print "Invalid source interface\n";
    }
    return;
}

sub is_destination_type {
    my ($stype) = @_;
    return $stype eq 'rspan-destination' || $stype eq 'erspan-destination';
}

sub show_source_interfaces {
    my ( $source_interfaces, $stype ) = @_;
    return if !defined($source_interfaces);
    printf $fmt, "  Source interfaces: ", "";
    foreach my $intf ( @{$source_interfaces} ) {
        printf $fmt, "    Name: ", $intf->{name};
        printf $fmt, "      Direction: ", $intf->{direction}
          if !is_destination_type($stype);
        foreach my $vlans ( [ 'RX', $intf->{rx_vlan} ], [ 'TX', $intf->{tx_vlan} ] ) {
            my ( $dir, $list ) = @{$vlans};
            printf $fmt, "      $dir vlans: ", join( ',', @{$list} )
              if defined($list) && @{$list};
        }
    }
    return;
}

sub show_session {
    my ( $entry, $sessionid ) = @_;
    my $sid = $entry->{session};
    die "Invalid portmonitor session $sessionid\n"
      unless defined($sid);

    my $stype = $entry->{type};
    printf $fmt, "Session: ", $sid;
    printf $fmt, "  Type: ",  $stype;
    printf $fmt, "  State: ", $entry->{state};
    if ( 'erspan-source' eq $stype || 'erspan-destination' eq $stype ) {
        printf $fmt, "  erspan Identifier: ", $entry->{erspanid};
        printf $fmt, "  erspan Header: ",     $erspanhdrs{ ( $entry->{erspanhdr} ) };
    }
    my $session_desc = $pmconfig->returnOrigValue("session $sid description");
    printf $fmt, "  Description: ", $session_desc if defined($session_desc);
    show_source_interfaces( $entry->{source_interfaces}, $stype );
    printf $fmt, "  Destination interface: ", $entry->{destination_interface}
      if defined( $entry->{destination_interface} );
    my $filters = $entry->{filters};
    if ( !is_destination_type($stype) && defined($filters) ) {
        printf $fmt, "  Filters: ", "";
        foreach my $filter ( @{$filters} ) {
            printf $fmt, "    Name: ",   $filter->{name};
            printf $fmt, "      Type: ", $filter->{type};
        }
    }
    return;
}

sub show_portmonitor {
    my ($sessionid) = @_;
    my ( $dpids, $dpsocks ) = Vyatta::Dataplane::setup_fabric_conns($fabric);
    die "Dataplane $fabric is not connected or does not exist\n"
      if defined($fabric) && !@{$dpids};

    for my $fid ( @{$dpids} ) {
        my $sock = ${$dpsocks}[$fid];
        die "Can not connect to dataplane $fid\n"
          unless defined($sock);

        my $cmd = "portmonitor show session";
        $cmd .= " $sessionid" if defined($sessionid);
        my $response = $sock->execute($cmd);
        exit 1 unless defined($response);

        print "\nvplane $fid:\n\n" if $fid != 0;

        my $session_array = decode_json($response)->{portmonitor_information};
        print "Portmonitor: No session is configured\n" if !@{$session_array};
        show_session( $_, $sessionid ) foreach @{$session_array};
    }
    Vyatta::Dataplane::close_fabric_conns( $dpids, $dpsocks );
    return;
}

sub allowed_portmonitor_sessions {
    foreach my $sid ( $pmconfig->listOrigNodes("session") ) {
        print "$sid\n";
    }
    return;
}
