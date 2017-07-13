package OpenXPKI::Server::Workflow::Validator::CommonNameLength;

use strict;
use warnings;
use utf8;

use Moose;

use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use English;
use Template;

use Data::Dumper;
use Encode;

extends 'OpenXPKI::Server::Workflow::Validator';

sub _validate {

    my ( $self, $workflow, $profile, $style, $subject_parts ) = @_;

    my $api     = CTX('api');

    return if (not defined $profile);
    return if (not defined $style);
    return if (not defined $subject_parts);

    # Render the DN - get the input data from the context
    if (!ref $subject_parts) {
        $subject_parts = OpenXPKI::Serialization::Simple->new()->deserialize( $subject_parts );
    }

    my $cert_subject = CTX('api')->render_subject_from_template({
        PROFILE => $profile,
        STYLE   => $style,
        VARS    => $subject_parts
    });

    return if (!$cert_subject);

    my $dn = new OpenXPKI::DN( $cert_subject );
    my %hash = $dn->get_hashed_content();

    if (length($hash{CN}[0]) > 64) {
        validation_error("I18N_OPENXPKI_UI_VALIDATOR_COMMON_NAME_TO_LONG");
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::CommonNameLength

=head1 Description

Check if the common name would be longer than 64 chars based on the given
profile and subject information. Internally renders the subject from the
information available and checks the length of the CN element.

=head1 Configuration

  vaidate_common_name_length:
    class: OpenXPKI::Server::Workflow::Validator::CommonNameLength
    arg:
      - $cert_profile
      - $cert_subject_style
      - $cert_san_parts


=head2 Argument

=over

=item profile

The name of the profile.

=item style

The name of the profile style.

=item subject_parts

The input parameters to perform the valdation on.

=back


