package OpenXPKI::Template::Plugin::DateTime;

=head1 OpenXPKI::Template::Plugin::DateTime

Plugin for Template::Toolkit to interact with OpenXPKI::DateTime

=cut

=head2 How to use

You need to load the plugin into your template before using it. As we do not
export the methods, you need to address them with the plugin name, e.g.

    [% USE DateTime %]
    [% DateTime.validity(timespec) %]

=cut

use strict;
use warnings;
use base qw( Template::Plugin );
use Template::Plugin;
use OpenXPKI::DateTime;

=head2 validity (timespec, reference)

Calculate the epoch timestamp from the given validity specification. Can
be any value recognized by OpenXPKI::DateTime::get_validity.

You can pass an epoch to use as reference, the default is now.

=cut

sub validity {

    my $self = shift;
    my $value = shift;
    my $reference = shift;

    my $refdate;
    if ($reference) {
        $refdate = DateTime->from_epoch( epoch => $reference );
    } else {
        $refdate = DateTime->now( time_zone => 'UTC' );
    }

    return OpenXPKI::DateTime::get_validity({
        REFERENCEDATE => $refdate,
        VALIDITY => $value,
        VALIDITYFORMAT => 'detect'
    })->epoch();

}

1;

__END__;
