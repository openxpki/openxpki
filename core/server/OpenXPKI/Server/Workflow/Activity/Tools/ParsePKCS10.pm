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
use Crypt::PKCS10;
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

    my $pkcs10 = $self->param('pkcs10');
    $pkcs10 = $context->param('pkcs10') unless($pkcs10);

    my $subject_prefix = $self->param('subject_prefix') || 'cert_';
    my $verify_signature = $self->param('verify_signature') ? 1 : 0;


    # Cleanup any existing values
    $context->param({
        'csr_subject' => '',
        'csr_subject_key_identifier' => '',
        'csr_signature_valid' => undef,
        $subject_prefix.'subject_parts' => '',
        $subject_prefix.'san_parts' => '',
        $subject_prefix.'subject_alt_name' => '',
        $subject_prefix.'info' => '',
    });

    # Source hash
    my $source_ref = {};
    my $ctx_source = $context->param('sources');
    if ($ctx_source) {
        $source_ref = $serializer->deserialize( $ctx_source );
    }

    # extract subject from CSR and add a context entry for it
    Crypt::PKCS10->setAPIversion(1);
    my $decoded = Crypt::PKCS10->new( $pkcs10, ignoreNonBase64 => 1, verifySignature => $verify_signature);

    # if decoded is not set we have either a parse error or a signature problem
    if (!$decoded) {
        my $error = Crypt::PKCS10->error;
        # if this works now it is the signature
        $decoded = Crypt::PKCS10->new($pkcs10,
            ignoreNonBase64 => 1,
            verifySignature => 0 );

        # if its still undef the structure is broken
        OpenXPKI::Exception->throw(
            message => 'PKCS10 structure can not be parsed: ' . $error
        ) unless ($decoded);

        CTX('log')->application()->warn("PKCS#10 signature invalid ($error)");

        $param->{'csr_signature_valid'} = 0;
    } elsif ($verify_signature) {
        $param->{'csr_signature_valid'} = 1;
        CTX('log')->application()->debug("PKCS#10 signature valid");
    }

    my %hashed_dn;
    my $csr_subject = $decoded->subject();

    if ($csr_subject) {
        # TODO - extend Crypt::PKCS10 to return RFC compliant subject
        my $dn = OpenXPKI::DN->new( $csr_subject );

        %hashed_dn = $dn->get_hashed_content();
        $param->{csr_subject} = $dn->get_rfc_2253_dn();
        ##! 32: 'Subject DN ' . Dumper \%hashed_dn
    }

    if ($self->param('key_params')) {

        $param->{csr_key_alg} = 'unsupported';
        $param->{csr_key_params} = {};
        eval {
            my $key_param = $decoded->subjectPublicKeyParams();
            if ($key_param->{keytype} eq 'RSA') {
                $param->{csr_key_alg} = 'rsa';
                $param->{csr_key_params} = { key_length =>  $key_param->{keylen} };
            } elsif ($key_param->{keytype} eq 'DSA') {
                $param->{csr_key_alg} = 'dsa';
                $param->{csr_key_params} = { key_length =>  $key_param->{keylen} };
            } elsif ($key_param->{keytype} eq 'ECC') {
                $param->{csr_key_alg} = 'ec';
                $param->{csr_key_params} = { key_length =>  $key_param->{keylen}, curve_name => $key_param->{curve} };
            }
        };
        if ($EVAL_ERROR) {
            CTX('log')->application()->warn("Unable to handle public key");
            CTX('log')->application()->debug($EVAL_ERROR);
        }

    } else {
        my $key_alg = $decoded->pkAlgorithm || '';
        if( $key_alg eq 'rsaEncryption' ) {
            $param->{csr_key_alg} = 'rsa';
        } elsif( $key_alg eq 'ecPublicKey' ) {
            $param->{csr_key_alg} = 'ec';
        } elsif( $key_alg eq 'dsa' ) {
            $param->{csr_key_alg} = 'dsa';
        } else {
            $param->{csr_key_alg} = 'unsupported';
        }
    }

    my @t = $decoded->signatureAlgorithm() =~ m{ (with-?(md5|sha\d+))|((md5|sha\d+)with) }ix;
    my ($csr_digest) = lc($t[1] || $t[3] || 'unknown');
    $param->{csr_digest_alg} = $csr_digest;

    $param->{csr_subject_key_identifier} =
        uc( join ':', ( unpack '(A2)*', sha1_hex(
                $decoded->{certificationRequestInfo}{subjectPKInfo}{subjectPublicKey}[0]
        )));


    # Get the profile name and style - required for templating
    my $cert_profile = $self->param('cert_profile');
    $cert_profile = $context->param('cert_profile') unless($cert_profile);

    my $cert_subject_style = $self->param('cert_subject_style');
    $cert_subject_style = $context->param('cert_subject_style') unless($cert_subject_style);

    # Map SAN keys from ASN1 names to openssl format (all uppercased)
    # TODO this should go to a central location
    my $san_map = {
        otherName => 'otherName',
        rfc822Name => 'email',
        dNSName => 'DNS',
        x400Address => '', # not supported by openssl
        directoryName => 'dirName',
        ediPartyName => '', # not supported by openssl
        uniformResourceIdentifier => 'URI',
        iPAddress  => 'IP',
        registeredID => 'RID',
    };

    my $csr_san = {};
    my @san_list;

    # Retrieve the registered SAN property names

    my @san_names = $decoded->subjectAltName();
    # Walk all san keys
    foreach my $san (@san_names) {
        my $san_type = $san_map->{$san};

        if (!$san_type) {
            # type is not supported
            next;
        }

        my @items = $decoded->subjectAltName( $san );

        # san hash
        $csr_san->{ $san_type } = \@items;

        # merge into dn, uppercase key name
        $hashed_dn{'SAN_'.uc($san_type)} = \@items;

        # push items to @san_list in the nested array format as required by

        # the csr persister
        foreach my $value (@items) {
            push @san_list, [ $san_type, $value ] if ($value);
        }

    }

    ##! 32: 'Extracted SAN ' . Dumper $csr_san

    ##! 32: 'Merged DN ' . Dumper \%hashed_dn

    # Attributes, must be a list of OIDs, seperated by comma/blank
    my $attr = $self->param('req_attributes');
    my $req_attr = {};
    if ($attr) {
        my @attr = split /[\s,]+/, $attr;
        foreach my $oid (@attr) {
            my $val = $decoded->attributes($oid);
            if ($val) {
                $req_attr->{$oid} =$val;
            }
         }
         $param->{req_attributes} = $req_attr;
         $source_ref->{req_attributes} = 'PKCS10';
    }

    # Extensions, must be a list of OIDs, seperated by comma/blank
    my $ext = $self->param('req_extensions');
    my $req_ext = {};
    if ($ext) {
        my @ext = split /[\s,]+/, $ext;
        foreach my $oid (@ext) {
            if ($decoded->extensionPresent($oid)) {
                $req_ext->{$oid} = $decoded->extensionValue($oid);
            }
         }
         $param->{req_extensions} = $req_ext;
         $source_ref->{req_extensions} = 'PKCS10';
    }

    # If the profile has NO ui section, we write the parsed hash and the SANs "as is" to the context
    if (!$cert_profile or !$cert_subject_style or !$config->exists(['profile', $cert_profile, 'style', $cert_subject_style, 'ui' ])) {

        $param->{$subject_prefix.'subject_parts'} = $serializer->serialize( \%hashed_dn ) ;
        $source_ref->{$subject_prefix.'subject_parts'} = 'PKCS10';

        if (scalar @san_list) {
            $param->{$subject_prefix.'subject_alt_name'} = $serializer->serialize( \@san_list );
            $source_ref->{$subject_prefix.'subject_alt_name'} = 'PKCS10';
        }

    } else {

        my $userinfo = CTX('session')->data->userinfo || {};
        my $cert_subject_parts = CTX('api2')->preset_subject_parts_from_profile(
            profile => $cert_profile,
            style => $cert_subject_style,
            section => 'subject',
            preset =>  { %hashed_dn, ( userinfo => $userinfo ) },
        );

        $param->{$subject_prefix.'subject_parts'} = $serializer->serialize( $cert_subject_parts );
        $source_ref->{$subject_prefix.'subject_parts'} = 'Parser';

        # Load the field spec for the san
        # FIXME: this implies that the id of the field matches the san types name
        # Evaluate: Replace with data from hashed_dn and preset?

        if ($csr_san) {
            my $san_names = CTX('api2')->list_supported_san();
            my $fields = CTX('api2')->get_field_definition( profile => $cert_profile, style => $cert_subject_style, section => 'san' );
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
                    if ($csr_san->{$case_key}) {
                        # check if it is a clonable field
                        if ($field->{clonable}) {
                            $cert_san_parts->{$key} = $csr_san->{$case_key};
                        } else {
                            $cert_san_parts->{$key} = $csr_san->{$case_key}->[0];
                        }
                    }
                }
            }
            ##! 16: 'san preset:' . Dumper $cert_san_parts
            if ($cert_san_parts) {
                $param->{$subject_prefix.'san_parts'} = $serializer->serialize( $cert_san_parts );
                $source_ref->{$subject_prefix.'san_parts'} = 'Parser';
            }
        }

        # call preset on cert_info block with userinfo from session
        my $cert_info = CTX('api2')->preset_subject_parts_from_profile(
            profile => $cert_profile,
            style => $cert_subject_style,
            section => 'info',
            preset => { userinfo => $userinfo },
        );
        if ($cert_info) {
            $param->{$subject_prefix.'info'} = $cert_info;
            $source_ref->{$subject_prefix.'info'} = 'Parser';
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

OpenXPKI::Server::Workflow::Activity::Tools::ParsePKCS10

=head1 Description

Take a pkcs10 container and extract information to the context. If a
profile name and style are given and the profile has a ui section, the
data extracted from the CSR is used to prefill the profile ui fields.
Otherwise the extracted subject and san information is put "as is" into
the context. Output definition is given below.

To get extra information from the CSR, add parameters key_params,
req_attributes and req_extensions to your activity configuration.

=head1 Configuration

=head2 Activity Parameters

=over

=item pkcs10

The PEM formatted pkcs10 request, has priority over context key.

=item cert_profile

Determines the used profile, has priority over context key.

=item cert_subject_style

Determines the used profile substyle, has priority over context key.

=item key_params

If set to a true value, details of the used public key are available
in the I<key_params> context entry. Requires Crypt::PK::ECC if ECC keys
need to be handled.

=item verify_signature

If set to a true value, the signature of the PKCS#10 container is checked
and the boolean result is written to csr_signature_valid. If not set, the
parameter is deleted from the context. It is recommended to check the
PCKS#10 container on upload already using the validator. Note that at least
the default backend will refuse broken signatures on the request to issue,
so you B<MUST> handle this.

=item subject_prefix

Prefix for context output keys to write the subject information into
(cert_subject_parts, cert_san_parts, cert_subject_alt_name).
Default is I<cert_>.

=back

=head2 Expected context values

=over

=item pkcs10

Read pkcs10 request from if not set using activity param.

=item cert_profile

Read cert_profile request from if not set using activity param.

=item cert_subject_style

Read cert_subject_style request from if not set using activity param.

=item req_extensions

List of OIDs (or names) of request extensions, multiple items must be
seperated by space. For each extensions that is found in the request,
a item in the req_extension context item is created. The key is the given
name, the content is the raw data as returned by Crypt::PKCS10 and depends
on the extensions.

=item req_attributes

List of OIDs (or names) of request attributes, similar to req_extension.

=back

=head2 Context value to be written

Prefix I<cert_> can be changed by setting I<subject_prefix>.

=over

=item csr_subject

The extracted subject as string (comma seperated)

=item cert_subject_parts

If a valid profile is given, contains the preset values for all fields given
in the profiles subject section. The values are determined by running the
appropriate template string for each field with the data extracted from the
csr.

In plain mode, it contains the parsed DN as key-value pairs where the key
is the shortname of the component (e.g: OU) and the value is an array of
values found. Note that any component is an array even if it has only one
item. All items found in the SAN part are also added with a prefix "SAN_"
and all uppercased names as used by openssl (SAN_OTHERNAME, SAN_EMAIL,
SAN_DNS, SAN_DIRNAME, SAN_URI, SAN_IP, SAN_RID)


=item cert_san_parts

Only in profile mode. Contains the preset values for all fields
given in the profiles san section. The values are determined by running the
appropriate template string for each field with the data extracted from the
csr.

=item cert_subject_alt_name

Only in plain mode. All SAN items as nested array list. Each item of the
list is a two item array with name and value of one SAN item. The names
are given as required to build then openssl extension file (otherName,
email, DNS, dirName, URI, IP, RID).

=item csr_key_alg

Algorithm of the public key, one of rsa, dsa, ec, unsupported

=item csr_digest_alg

The digest algorithm used to create the signature request (e.g. md5, sha1).

=item csr_key_params

Hash holding additional information on the used public key, only present
if key_params is set. Keys depend on the type of the key.

=over

=item key_length

Size of the used public key (RSA/DSA)/curve (ECC) in bits

=item curve

ec keys only, name of the curve - can be empty if curve is not known to
the current openssl version or if custom parameters have been used.

=back

=item csr_subject_key_identifier

The key identifier of the used public key, Hex with uppercased letters.
The format is identical to the return value of the API method
get_key_identifier_from_data and the format used in the certificates table.

=item csr_signature_valid

Boolean, set only if I<validate_signature> is set and recevies a literal
0/1 weather the PKCS#10 containers signature can be validated.

=back
