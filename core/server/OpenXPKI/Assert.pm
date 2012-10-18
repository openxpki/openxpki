## OpenXPKI::Assert
##
## Quick-n-Dirty tool for transition from xml to Config::Versioned
##

package OpenXPKI::Assert;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(assert_is);
use Carp qw(croak);
use OpenXPKI::Exception;

sub assert_is {
    my $got      = $_[0];
    my $expected = $_[1];
    my $text     = $_[2];

    if ( $got ne $expected ) {
        my @msg = ();
        push @msg, "Assert failed:";
        push @msg, "     Got: '" . $got . "'";
        push @msg, "Expected: '" . $expected . "'";
        push @msg, ' Details: ' . $text || '<none>';

        OpenXPKI::Exception->throw( message => join( "\n\t", @msg ) );
    }
}

