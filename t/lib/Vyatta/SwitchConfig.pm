# Test stub for Vyatta::SwitchConfig: STUB_HW_INTERFACES lists the
# hardware-switched interfaces.
package Vyatta::SwitchConfig;
use strict;
use warnings;
use parent qw(Exporter);
our @EXPORT_OK = qw(is_hw_interface);

sub is_hw_interface {
    my ($name) = @_;
    return grep { $_ eq $name } split q{ }, $ENV{STUB_HW_INTERFACES} // q{};
}

1;
