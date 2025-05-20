package OpenXPKI::Server::Workflow::Validator::CertSubjectFields;
use OpenXPKI -class;

extends 'OpenXPKI::Server::Workflow::Validator';

use Workflow::Exception qw( validation_error );
use Template;

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
        my $min = $field->{min} || 0;
        my $max = $field->{max} || 0;
        my $match = $field->{match} || '';
        my $clonable =  $field->{clonable} || 0;

        my @value;
        if ( !defined $subject_parts->{ $name } ) {
            # noop
        } elsif (ref $subject_parts->{ $name } eq 'ARRAY') {
            @value = @{$subject_parts->{ $name }};
        } elsif ( $subject_parts->{ $name } ne '' ) {
            @value = ( $subject_parts->{ $name } );
        }

        # remove from hash to see if all was check
        delete $subject_parts->{ $name };

        # we need to form field name in the json reply
        $name = sprintf "%s{%s}", $basename, $name if $basename; # search tag: #wf_fields_with_sub_items

        # if the field is a cloneable, the name ends on square brackets
        if ($clonable) {
            $name .= '[]';
        }

        my @nonempty = grep { (defined $_ && $_ ne '') } @value;
        if (@nonempty < $min) {
            push @fields_with_error, { name => $name, min => $min,
                error => 'I18N_OPENXPKI_UI_VALIDATOR_CERT_SUBJECT_FIELD_LESS_THAN_MIN_COUNT' };
            next FIELD;
        }

        if ($max && $max < scalar @nonempty) {
            # push an error to the fields that need to be removed
            my $ii = scalar @nonempty;
            do {
                push @fields_with_error, { name => $name, max => $max, index => --$ii,
                    error => 'I18N_OPENXPKI_UI_VALIDATOR_CERT_SUBJECT_FIELD_MAX_COUNT_EXCEEDED' };
            } while ($ii > $max);
            next FIELD;
        }

        if ($match) {
            my $ii = 0;
            foreach my $val (@nonempty) {
                if ($val ne '' && $val !~ m{$match}xs) {
                    # should be a bit smarter to highlight the right one
                    push @fields_with_error, { name => $name,
                        error => 'I18N_OPENXPKI_UI_VALIDATOR_CERT_SUBJECT_FIELD_FAILED_REGEX', index => $ii };
                }
                $ii++;
            }
        }
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

