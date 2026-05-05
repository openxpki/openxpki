package OpenXPKI::Server::Workflow::Validator::CertSubjectFields;
use OpenXPKI -class;

extends 'OpenXPKI::Server::Workflow::Validator';

use Workflow::Exception qw( validation_error );
use Template;

use OpenXPKI::Workflow::Field;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;


sub _validate {

    my ( $self, $workflow, $profile, $style, $subject_parts ) = @_;

    return if (not defined $profile);
    return if (not defined $style);
    return if (not defined $subject_parts);

    my $basename = $self->param('basename');
    ##! 16: 'Basename ' . $basename

    my @fields_with_error;

    ##! 16: 'wf->id(): ' . $wf->id()

    my $fields = CTX('api2')->get_field_definition(
        profile => $profile,
        style   => $style,
        section => $self->param('section'),
    );

    ##! 64: 'fields: ' . Dumper $fields

    my $ser = OpenXPKI::Serialization::Simple->new();
    $subject_parts = $ser->deserialize( $subject_parts );

    ##! 64: 'data: ' . Dumper $subject_parts
    # check min/max and match from the input definition
    # match: \A [A-Za-z\d\-\.]+ \z
    # min: 0
    # max: 100
    FIELD:
    foreach my $field (@$fields) {

        my $name = $field->{name};
        my $obj = OpenXPKI::Workflow::Field->new(
            field => $field,
            path => [],
        );

        my @errors = $obj->validate($subject_parts->{ $name });

        # remove from hash to see if all was check
        delete $subject_parts->{ $name };

        if (@errors && $basename) {
            # upgrade the name field with the basename
            $name = sprintf "%s{%s}", $basename, $name;
            @errors = map { $_->{name} = $name; $_ } @errors;
        }
        push @fields_with_error, @errors;

    }

    foreach my $name (keys %$subject_parts) {
        push @fields_with_error, { name => $name, error => 'I18N_OPENXPKI_UI_VALIDATOR_CERT_SUBJECT_FIELD_NOT_DEFINED' };
    }

    ## did we find any errors?
    if (@fields_with_error) {
       CTX('log')->application()->error("Certificate subject validation error");

        validation_error ('I18N_OPENXPKI_UI_VALIDATOR_CERT_SUBJECT_FIELD_HAS_ERRORS', { invalid_fields => \@fields_with_error } );
    }

    return 1;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::CertSubjectFields

=head1 SYNOPSIS

  vaidate_san_parts:
    class: OpenXPKI::Server::Workflow::Validator::CertSubjectFields
    param:
      section: san
    arg:
      - $cert_profile
      - $cert_subject_style
      - $cert_san_parts

=head1 DESCRIPTION

Validate input for certificate subject information as defined in the
profile definition.

=head2 Argument

=over

=item profile

The name of the profile.

=item style

The name of the profile style.

=item subject_parts

The input parameters to perform the valdation on.

=back

=head2 Parameter

=over

=item section

The name of the section to perform checks on (B<subject>, san, info).

=item basename

The name of the form parameter used for this information. This is used
to generate the list of errornous fieldnames for the UI. If omitted, the
context keys are used.

=back

