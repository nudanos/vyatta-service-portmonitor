# Test stub for Vyatta::Interface: dpXsY[.vif] are dataplane interfaces,
# dp0bondN bonding, vhostN vhost; anything else is unknown.
package Vyatta::Interface;
use strict;
use warnings;

my @types = (
    [ qr/^dp\d+s\d+(?:[.]\d+)?$/x, 'dataplane' ],
    [ qr/^dp\d+bond\d+$/x,         'bonding' ],
    [ qr/^vhost\d+$/x,             'vhost' ],
);

sub new {
    my ( $class, $name ) = @_;
    foreach my $t (@types) {
        return bless { name => $name, type => $t->[1] }, $class if $name =~ $t->[0];
    }
    return;
}

sub type { my ($self) = @_; return $self->{type}; }

sub path {
    my ($self) = @_;
    my ( $base, $vif ) = split /[.]/x, $self->{name};
    return "interfaces $self->{type} $base" . ( defined $vif ? " vif $vif" : q{} );
}

sub is_valid_intf_cfg { my ($name) = @_; return defined Vyatta::Interface->new($name); }

1;
