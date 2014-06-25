# OpenXPKI::Server::Workflow::Activity::Tools::ParsePKCS10
# Copyright (c) 2014 by The OpenXPKI Project
# Largely copied from SCEPv2::ExtractCSR

package OpenXPKI::Server::Workflow::Activity::Tools::ParsePKCS10;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use OpenXPKI::DN;
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;
use Template;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;

    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $context   = $workflow->context();
    my $config = CTX('config');

    my $pkcs10 = $context->param('pkcs10');

    my $default_token = CTX('api')->get_default_token();

    # Cleanup any existing values
    $context->param( 'csr_subject' => '' );
    $context->param( 'cert_subject_parts' => '' );
    $context->param( 'cert_san_parts' => '' );

    # extract subject from CSR and add a context entry for it
    my $csr_obj = OpenXPKI::Crypto::CSR->new(
        DATA  => $pkcs10,
        TOKEN => $default_token
    );

    my $csr_body = $csr_obj->get_parsed_ref()->{BODY};
    ##! 32: 'csr_parsed: ' . Dumper $csr_body

    my $csr_subject = $csr_body->{'SUBJECT'};
    # Explicit check for empty subject - should never happen but if it crashes the logic
    if (!$csr_subject) {
        CTX('log')->log(
            MESSAGE => "csr has no subject",
            PRIORITY => 'warn',
            FACILITY => 'application',
        );
        return 1;
    }

    my $csr_key_size = $csr_body->{KEYSIZE};
    my $csr_key_type = $csr_body->{PUBKEY_ALGORITHM};

    $context->param('csr_subject' => $csr_subject);
    $context->param('csr_key_size' => $csr_key_size );
    $context->param('csr_key_type' => $csr_key_type );


    my $cert_profile = $context->param( 'cert_profile' );
    my $cert_subject_style = $context->param( 'cert_subject_style' );

    my %hashed_dn = OpenXPKI::DN->new( $csr_subject )->get_hashed_content();
    ##! 32: 'DN ' . Dumper \%hashed_dn

    # Load the field spec for the subject
    my $fields = CTX('api')->get_field_definition( { PROFILE => $cert_profile, STYLE => $cert_subject_style, SECTION => 'subject' });

    my $tt = Template->new();
    my $cert_subject_parts;
    FIELDS:
    foreach my $field (@{$fields}) {
        # Check if there is a preset template
        my $preset = $field->{PRESET};
        next FIELDS unless ($preset);

        my $val;
        # Fast path, copy from DN
        if ($preset =~ m{ \A \s* (\w+)(\.(\d+))? \s* \z }xs) {
            my $comp = $1;
            my $pos = $3 || 0;
            $val = $hashed_dn{$comp}[$pos];
            if ($val) {
                $cert_subject_parts->{ $field->{ID} } = $val;
            }
        # Should be a TT string
        } else {
            $tt->process(\$preset, \%hashed_dn, \$val) || OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_ACTIVITY_PARSE_PKCS10_TT_DIED',
                params => { PROFILE => $cert_profile, STYLE => $cert_subject_style, FIELD => $field, PATTERN => $preset }
            );
            if ($val) {
                $cert_subject_parts->{ $field->{ID} } = $val;
            }
        }

        CTX('log')->log(
            MESSAGE => "subject preset - field $field, pattern $preset, value $val",
            PRIORITY => 'debug',
            FACILITY => 'application',
        );

    }
    $context->param('cert_subject_parts' => $serializer->serialize( $cert_subject_parts ) );

    my $csr_san = $csr_obj->get_subject_alt_names({ FORMAT => 'HASH' });
    ##! 16: 'Found san in csr :' . Dumper $csr_san
    # Load the field spec for the san
    if ($csr_san) {
        my $san_names = CTX('api')->list_supported_san();
        $fields = CTX('api')->get_field_definition( { PROFILE => $cert_profile, STYLE => $cert_subject_style, SECTION => 'san' });
        ##! 16: 'san ui definition:' . Dumper $fields
        my $cert_san_parts;
        # Get all allowed san types
        foreach my $field (@{$fields}) {
            my $keys = ref $field->{KEYS} ? $field->{KEYS} : [ $field->{ID} ];
            ##! 16: 'testing keys:' . join "-", @{$keys}
            foreach my $key (@{$keys}) {
                # hash items are mixed case
                # user might also use wrong camelcasing
                # the target hash is all lowercased
                $key = lc($key);
                my $case_key = $san_names->{$key};
                if ($csr_san->{$case_key}) {
                    # check if it is a clonable field
                    if ($field->{CLONABLE}) {
                        $cert_san_parts->{$key} = $csr_san->{$case_key};
                    } else {
                        $cert_san_parts->{$key} = $csr_san->{$case_key}->[0];
                    }
                }
            }
        }
        ##! 16: 'san preset:' . Dumper $cert_san_parts
        $context->param('cert_san_parts' => $serializer->serialize( $cert_san_parts ) ) if ($cert_san_parts);
    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::ParsePKCS10

=head1 Description

Take a pkcs10 container from the context and extract information to the
context. The context values are prepared to prefill the subject/san form
based on the given profile and style.

=head2 Expected context values

=over

=item pkcs10

=item cert_profile

=item cert_subject_style

=back

=head2 Context value to be written

=over

=item csr_subject

The extracted subject as string

=item cert_subject_parts

Hash to prefill the subject template based.

=item cert_san_parts

Hash to prefill the san template. Extensions without a machting rule in the
form definition are deleted.

=back