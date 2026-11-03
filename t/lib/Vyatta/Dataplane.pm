# Test stub for Vyatta::Dataplane: one dataplane whose socket answers
# "portmonitor show session ..." with the JSON in STUB_SHOW.
package Vyatta::Dataplane;
use strict;
use warnings;

sub setup_fabric_conns { return ( [0], [ bless {}, 'Vyatta::Dataplane::Sock' ] ); }
sub close_fabric_conns { return; }

package Vyatta::Dataplane::Sock;    ## no critic (Modules::ProhibitMultiplePackages) reason: the socket class the stub hands out

sub execute {
    my ( undef, $cmd ) = @_;
    print "[dataplane: $cmd]\n";
    return $ENV{STUB_SHOW};
}

1;
