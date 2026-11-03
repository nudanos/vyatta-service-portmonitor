# Test stub for Vyatta::Platform: the portmonitor limits are the JSON in
# STUB_LIMITS; features listed in STUB_FEATURES are supported.
package Vyatta::Platform;
use strict;
use warnings;
use JSON::PP;
use parent qw(Exporter);
our @EXPORT_OK = qw(get_platform_feature_limits is_supported_platform_feature);

sub get_platform_feature_limits {
    my ( undef, $defaults ) = @_;
    return ( %{$defaults}, %{ decode_json( $ENV{STUB_LIMITS} // '{}' ) } );
}

sub is_supported_platform_feature {
    my ($feature) = @_;
    return grep { $_ eq $feature } split q{ }, $ENV{STUB_FEATURES} // q{};
}

1;
