# Test stub for Vyatta::Config: the candidate tree is the JSON in
# STUB_CONFIG, the running one STUB_ORIG, both keyed by full path from the
# root ("service portmonitor", "interfaces dataplane", ...). A leaf is a
# string, a multi value a list, a node an object.
package Vyatta::Config;
use strict;
use warnings;
use JSON::PP;

sub new {
    my ( $class, $level ) = @_;
    return bless { level => $level // q{} }, $class;
}

sub lookup {
    my ( $self, $var, $path ) = @_;
    my $node = decode_json( $ENV{$var} // '{}' );
    foreach my $word ( split q{ }, "$self->{level} " . ( $path // q{} ) ) {
        return if ref $node ne 'HASH' || !exists $node->{$word};
        $node = $node->{$word};
    }
    return \$node;
}

sub listNodes {
    my ( $self, $path ) = @_;
    my $node = $self->lookup( 'STUB_CONFIG', $path ) or return;
    return ref ${$node} eq 'HASH' ? sort keys %{ ${$node} } : ();
}

sub returnValue {
    my ( $self, $path ) = @_;
    my $node = $self->lookup( 'STUB_CONFIG', $path ) or return;
    return ref ${$node} ? undef : ${$node};
}

sub returnOrigValue {
    my ( $self, $path ) = @_;
    my $node = $self->lookup( 'STUB_ORIG', $path ) or return;
    return ref ${$node} ? undef : ${$node};
}

sub returnValues {
    my ( $self, $path ) = @_;
    my $node = $self->lookup( 'STUB_CONFIG', $path ) or return;
    return ref ${$node} eq 'ARRAY' ? @{ ${$node} } : ();
}

## no critic (Subroutines::ProhibitBuiltinHomonyms) reason: Vyatta::Config's method name
sub exists {
    my ( $self, $path ) = @_;
    return $self->lookup( 'STUB_CONFIG', $path ) ? 1 : undef;
}
## use critic

sub isDefault { return; }

sub returnOrigValues {
    my ( $self, $path ) = @_;
    my $node = $self->lookup( 'STUB_ORIG', $path ) or return;
    return ref ${$node} eq 'ARRAY' ? @{ ${$node} } : ();
}

# a multi value's elements count as nodes for isAdded/isDeleted
sub in_tree {
    my ( $self, $var, $path ) = @_;
    return 1 if $self->lookup( $var, $path );
    my ( $parent, $leaf ) = $path =~ m{^(.*)[ ](\S+)$}x or return 0;
    my $node = $self->lookup( $var, $parent ) or return 0;
    return ref ${$node} eq 'ARRAY' && grep { $_ eq $leaf } @{ ${$node} };
}

sub isAdded {
    my ( $self, $path ) = @_;
    return $self->in_tree( 'STUB_CONFIG', $path ) && !$self->in_tree( 'STUB_ORIG', $path );
}

sub isDeleted {
    my ( $self, $path ) = @_;
    return !$self->in_tree( 'STUB_CONFIG', $path ) && $self->in_tree( 'STUB_ORIG', $path );
}

sub isChanged {
    my ( $self, $path ) = @_;
    my $new  = $self->lookup( 'STUB_CONFIG', $path ) or return 0;
    my $orig = $self->lookup( 'STUB_ORIG',   $path ) or return 0;
    my $json = JSON::PP->new->canonical;
    return $json->encode( [ ${$new} ] ) ne $json->encode( [ ${$orig} ] );
}

sub listOrigNodes {
    my ( $self, $path ) = @_;
    my $node = $self->lookup( 'STUB_ORIG', $path ) or return;
    return ref ${$node} eq 'HASH' ? sort keys %{ ${$node} } : ();
}

sub existsOrig {
    my ( $self, $path ) = @_;
    return $self->lookup( 'STUB_ORIG', $path ) ? 1 : undef;
}

sub listDeleted {
    my ( $self, $path ) = @_;
    my $orig = $self->lookup( 'STUB_ORIG', $path ) or return;
    my @was  = ref ${$orig} eq 'ARRAY' ? @{ ${$orig} } : sort keys %{ ${$orig} };
    my %now  = map { $_ => 1 } $self->listNodes($path), $self->returnValues($path);
    return grep { !$now{$_} } @was;
}

1;
