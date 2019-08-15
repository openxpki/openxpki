
package OpenXPKI::Server::Workflow::Activity::Tools::PresetProfileFields;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use OpenXPKI::DN;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;
use Template;
use Digest::SHA qw(sha1_hex);

sub execute {

    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;

    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $context   = $workflow->context();

    my $param = {}; # hash to receive the context updates
    my $config = CTX('config');

    # Cleanup any existing values
    $context->param({
        'cert_subject_parts' => '',
        'cert_san_parts' => '',
    });

    my $cert_subject = $self->param('cert_subject') || $context->param('cert_subject');
    if (!$cert_subject) {
        return;
    }

    # Source hash
    my $source_ref = {};
    my $ctx_source = $context->param('sources');
    if ($ctx_source) {
        $source_ref = $serializer->deserialize( $ctx_source );
    }


    my $dn = OpenXPKI::DN->new( $cert_subject );
    my %hashed_dn = $dn->get_hashed_content();

    # Get the profile name and style - required for templating
    my $cert_profile = $self->param('cert_profile') || $context->param('cert_profile');
    my $cert_subject_style = $self->param('cert_subject_style') || $context->param('cert_subject_style');
    my $subject_alt_name = $self->param('cert_subject_alt_name') || $context->param('cert_subject_alt_name');

    ##! 32: 'Raw SAN ' . Dumper $subject_alt_name

    # if san is in array format, map to hash first
    my $san_hash = {};
    if ($subject_alt_name) {

        if (!ref $subject_alt_name) {
           # need deserialize
           $subject_alt_name = $serializer->deserialize($subject_alt_name);
        }
        if (ref $subject_alt_name eq 'ARRAY') {

            foreach my $san (@{$subject_alt_name}) {
                my $type = $san->[0];
                my $val = $san->[1];
                if ($san_hash->{$type}) {
                    push @{$san_hash->{$type}}, $val;
                } else {
                    $san_hash->{$type} = [ $val ];
                }
            }

        } else {
            $san_hash = $subject_alt_name;
        }
    }

    foreach my $san_type (keys %{$san_hash}) {
        # merge into dn, uppercase key name
        $hashed_dn{'SAN_'.uc($san_type)} = $san_hash->{$san_type};
    }

    ##! 32: 'Extracted SAN ' . Dumper $san_hash

    ##! 32: 'Merged DN ' . Dumper \%hashed_dn


    my $cert_subject_parts = CTX('api2')->preset_subject_parts_from_profile(
        profile => $cert_profile,
        style => $cert_subject_style,
        section => 'subject',
        preset => \%hashed_dn
    );

    $param->{'cert_subject_parts'} = $serializer->serialize( $cert_subject_parts );
    $source_ref->{'cert_subject_parts'} = 'Parser';

    # Load the field spec for the san
    # FIXME: this implies that the id of the field matches the san types name
    # Evaluate: Replace with data from hashed_dn and preset?

    if ($san_hash) {
        my $san_names = CTX('api2')->list_supported_san();
        my $fields = CTX('api2')->get_field_definition(
            profile => $cert_profile,
            style => $cert_subject_style,
            section => 'san'
        );
        ##! 16: 'san ui definition:' . Dumper $fields
        my $cert_san_parts;
        # Get all allowed san types
        foreach my $field (@{$fields}) {
            my $keys = ref $field->{keys} ? $field->{keys} : [ $field->{id} ];
            ##! 16: 'testing keys:' . join "-", @{$keys}
            foreach my $key (@{$keys}) {
                # hash items are mixed case
                # user might also use wrong camelcasing
                # the target hash is all lowercased
                $key = lc($key);
                my $case_key = $san_names->{$key};
                if ($san_hash->{$case_key}) {
                    # check if it is a clonable field
                    if ($field->{clonable}) {
                        $cert_san_parts->{$key} = $san_hash->{$case_key};
                    } else {
                        $cert_san_parts->{$key} = $san_hash->{$case_key}->[0];
                    }
                }
            }
        }
        ##! 16: 'san preset:' . Dumper $cert_san_parts
        if ($cert_san_parts) {
            $param->{'cert_san_parts'} = $serializer->serialize( $cert_san_parts );
            $source_ref->{'cert_san_parts'} = 'Parser';
        }
    }

    ##! 64: 'Params to set ' . Dumper $param
    $context->param( $param );
    $context->param('sources' => $serializer->serialize( $source_ref) );

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::PresetProfileFields

=head1 Description

This activity presets the certificate profile fields similar to
OpenXPKI::Server::Workflow::Activity::Tools::ParsePKCS10 but uses the
information about subject and SAN from the context instead of reading them
from the PKCS10 request.

=head1 Configuration

=head2 Activity Parameters

=over

=item cert_subject

The subject to use as string, has priority over context key.

=item cert_profile

Determines the used profile, has priority over context key.

=item cert_subject_style

Determines the used profile substyle, has priority over context key.

=back

=head2 Expected context values

=over

=item cert_subject

Read cert_subject from if not set using activity param.

=item cert_profile

Read cert_profile request from if not set using activity param.

=item cert_subject_style

Read cert_subject_style request from if not set using activity param.

=back

=head2 Context value to be written

=over

=item cert_subject_parts

Contains the preset values for all fields given
in the profiles subject section. The values are determined by running the
appropriate template string for each field with the data extracted from the
csr.

=item cert_san_parts

Contains the preset values for all fields
given in the profiles san section. The values are determined by running the
appropriate template string for each field with the data extracted from the
csr.

=back
