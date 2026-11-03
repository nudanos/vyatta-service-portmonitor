# Test stub for Vyatta::VPlaned: each store is printed as
# "<action> <key> => <command> [<interface>]".
package Vyatta::VPlaned;
use strict;
use warnings;

sub new { return bless {}, shift; }

sub store {
    my ( undef, $key, $cmd, $interface, $action ) = @_;
    printf "%s %s => %s [%s]\n", $action, $key, $cmd, $interface // 'undef';
    return;
}

1;
