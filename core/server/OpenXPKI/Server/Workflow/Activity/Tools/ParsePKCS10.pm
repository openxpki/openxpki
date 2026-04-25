package OpenXPKI::Server::Workflow::Activity::Tools::ParsePKCS10;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Activity );

use Crypt::PKCS10;
use Digest::SHA qw(sha1_hex);
use MIME::Base64;
use Template;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypt::DN;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Util;
use Workflow::Exception qw(configuration_error workflow_error);

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
    my $skip_sanitize = $self->param('skip_sanitize') ? 1 : 0;

    my $target_key = $self->param('target_key');

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

    my $decoded = Crypt::PKCS10->new( $pkcs10,
        ignoreNonBase64 => 1,
        verifySignature => 0 );

    my $error;
    $error = Crypt::PKCS10->error unless($decoded);

    # try to unwrap as PKCS7 renewal request containers if allowed
    if (!$decoded && $self->param('unwrap_pkcs7')) {

        eval{
            ##! 16: 'try to parse a PKCS7'
            my $p7 = OpenXPKI::Crypt::PKCS7->new($pkcs10);
            ##! 128: $p7->envelope()
            $pkcs10 = $p7->payload();
            ##! 32: encode_base64($pkcs10)
            $decoded = Crypt::PKCS10->new( $pkcs10,
                ignoreNonBase64 => 1,
                verifySignature => 0 );

            die Crypt::PKCS10->error unless($decoded);

            # set target_key to enforce write back to context
            $target_key ||= 'pkcs10';
            $error = undef;
            CTX('log')->application()->info("Input was PKCS7 container, unwrapped payload");
        };
        $error = $EVAL_ERROR if($EVAL_ERROR);
    }

    workflow_error('PKCS10 structure can not be parsed', { error => $error }) unless($decoded);

    if ($verify_signature) {
        if ($decoded->checkSignature()) {
            $param->{'csr_signature_valid'} = 1;
            CTX('log')->application()->debug("PKCS#10 signature valid");
        } else {
            $param->{'csr_signature_valid'} = 0;
            CTX('log')->application()->warn("PKCS#10 signature invalid ($error)");
        }
    }

    # write back the cleaned PEM block if target_key is set
    $param->{$target_key} = $decoded->csrRequest(1) if ($target_key);

    my $hashed_dn;
    if (my $csr_subject = $decoded->subjectSequence()) {
        my $dn = OpenXPKI::Crypt::DN->new( sequence => $csr_subject );
        $hashed_dn = $dn->as_hash();
        unless ($skip_sanitize) {
            foreach my $rdn (keys $hashed_dn->%*) {
                my @filtered = grep { OpenXPKI::Util->validate('GeneralName', $_) } $hashed_dn->{$rdn}->@*;
                if (@filtered) {
                    CTX('log')->application()->warn("RDN $rdn was reduced by sanitize")
                        if (@filtered != $hashed_dn->{$rdn}->@*);
                    $hashed_dn->{$rdn} = \@filtered;
                } else {
                    CTX('log')->application()->warn("RDN $rdn empty after sanitize");
                    delete $hashed_dn->{$rdn};
                }
            }
        }
        $param->{csr_subject} = $dn->get_subject();
        ##! 32: 'Subject DN ' . Dumper $hashed_dn
    }
    # ensure that this is not undef as we convert it later to hash
    $hashed_dn //= {};

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
        # TODO otherName is returned as hash with OID and stringified value
        # need to find a suitable way to extract and encode this
        #otherName => 'otherName',
        rfc822Name => 'email',
        dNSName => 'DNS',
        x400Address => '', # not supported by openssl
        # the parser chokes on dirName - needs investigatin
        #directoryName => 'dirName',
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

        my @items;
        # no sanitazion is wanted - map values directly
        if ($skip_sanitize) {
            @items = $decoded->subjectAltName( $san );
        } else {
            @items = $self->sanitize_san_item( $san, $decoded->subjectAltName( $san ) );
        }

        next unless @items;

        # san hash
        $csr_san->{ $san_type } = \@items;

        # merge into dn, uppercase key name
        $hashed_dn->{'SAN_'.uc($san_type)} = \@items;

        # push items to @san_list in the nested array format as required by

        # the csr persister
        foreach my $value (@items) {
            push @san_list, [ $san_type, $value ] if ($value);
        }

    }

    ##! 32: 'Extracted SAN ' . Dumper $csr_san

    ##! 32: 'Merged DN ' . Dumper $hashed_dn

    # Request Attributes
    my $attr = $self->param('req_attributes');
    my $req_attr = $self->hande_extensions( $attr, sub {
        return $decoded->attributes(shift);
    });

    if ($req_attr) {
        $param->{req_attributes} = $req_attr;
        $source_ref->{req_attributes} = 'PKCS10';
    }

    # Request Extensions
    my $ext = $self->param('req_extensions');
    my $req_ext = $self->hande_extensions( $ext, sub {
        my $oid = shift;
        return $decoded->extensionValue($oid) if ($decoded->extensionPresent($oid));
    });

    if ($req_ext) {
        $param->{req_extensions} = $req_ext;
        $source_ref->{req_extensions} = 'PKCS10';
    }

    # If the profile has NO ui section, we write the parsed hash and the SANs "as is" to the context
    if (!$cert_profile or !$cert_subject_style or !$config->exists(['profile', $cert_profile, 'style', $cert_subject_style, 'ui' ])) {

        $param->{$subject_prefix.'subject_parts'} = $serializer->serialize( $hashed_dn ) ;
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
            preset =>  { %{$hashed_dn}, ( userinfo => $userinfo ) },
        );

        $param->{$subject_prefix.'subject_parts'} = $serializer->serialize( $cert_subject_parts );
        $source_ref->{$subject_prefix.'subject_parts'} = 'Parser';

        # Load the field spec for the san
        # FIXME: this implies that the id of the field matches the san types name
        # Evaluate: Replace with data from hashed_dn and preset?

        if ($csr_san) {
            my $san_names = CTX('api2')->list_supported_san();
            my $fields = CTX('api2')->get_field_definition(
                profile => $cert_profile,
                style => $cert_subject_style,
                section => 'san',
            );
            ##! 16: 'san ui definition:' . Dumper $fields
            my $cert_san_parts;
            # Get all allowed san types
            foreach my $field (@{$fields}) {
                my $keys = ref $field->{keys} ? $field->{keys} : [ $field->{name} ];
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
            preset => { %{$hashed_dn}, ( userinfo => $userinfo ) },
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

sub sanitize_san_item {

    my ($self, $san_type, @values) = @_;

    my %type_map = (
        dNSName                   => 'DNSName',
        rfc822Name                => 'Email',
        iPAddress                 => 'IP',
        uniformResourceIdentifier => 'URI',
        registeredID              => 'OID',
        directoryName             => 'ParsedDN',
        otherName                 => 'GeneralName',
    );

    my $type_name = $type_map{$san_type};

    my @valid;
    for my $value (@values) {
        next unless (defined $value && $value ne '');
        if ($type_name && !OpenXPKI::Util->validate($type_name, $value)) {
            CTX('log')->application()->warn(
                sprintf("Ignoring invalid SAN value for type %s: %s", $san_type, $value)
            );
            next;
        }
        push @valid, $value;
    }

    return @valid;

}

# wrapper method to handle extraction of attributes and extensions
sub hande_extensions {

    my $self = shift;
    my $oidlist = shift;
    my $callback = shift;

    return unless ($oidlist);

    my @oids;
    # legacy format, a single string, multiple items separated by space/comma
    if (ref $oidlist eq '') {
        @oids = split /[\s,]+/, $oidlist;

    # list of items
    } elsif (ref $oidlist eq 'ARRAY') {
        @oids = $oidlist->@*;

    } else {

        configuration_error('unsupported format of oidlist')
    }

    my $parsed;
    foreach my $oid (@oids) {

        # use the callback to fetch the raw value
        # this is a raw asn1 tag for unnamed oids
        # but a known structure for named items
        my $val = $callback->($oid);
        next unless (defined $val);

        ##! 16: $oid
        ##! 32: $val
        $parsed->{$oid} = $val;

    }
    return $parsed;

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::ParsePKCS10

=head1 Description

Take a pkcs10 container and extract information to the context. A basic format
validation is done on extracted SAN items to catch broken data early, malformed
data is filtered out and a warning is issued.

If a profile name and style are given and the profile has a ui section, the
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

=item skip_sanitize

If set to a true value, the SAN item validation is skipped and any content
is mapped.

=item subject_prefix

Prefix for context output keys to write the subject information into
(cert_subject_parts, cert_san_parts, cert_subject_alt_name).
Default is I<cert_>.

=item target_key

If set, the "cleaned" PKCS10 container is written back to this context
value. This is useful if you have a "dirty" input.
When combined with the I<unwrap_pkcs7> this receives the extracted
PEM encodede request.

=item unwrap_pkcs7

Renewal requests made by e.g. windows servers come with the PEM headers
of a "normal" PKCS10 formatted request but are enveloped into a PKCS7
signature. When set to a true value, the class will extract the payload
from the given container and write it back to I<target_key>. If not set,
the container is written to I<pkcs10>.

=item req_attributes

A list of named attributes or OIDs to extract from the CSR, result goes
into the context value of the same name.
For details see the section L<Extension Handling> below.

=item req_extensions

A list of named extensions or OIDs to extract from the CSR, result goes
into the context value of the same name.
For details see the section L<Extension Handling> below.

=back

=head2 Expected context values

=over

=item pkcs10

Read pkcs10 request from if not set using activity param.

=item cert_profile

Read cert_profile request from if not set using activity param.

=item cert_subject_style

Read cert_subject_style request from if not set using activity param.

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

B<Note>: C<otherName> and C<dirName> are not yet supported and not extracted.

=item csr_key_alg

Algorithm of the public key, one of rsa, dsa, ec, unsupported

=item csr_digest_alg

The digest algorithm used to create the signature request (e.g. md5, sha1).

=item csr_key_params

Hash holding additional information on the used public key, only present
if key_params is set. Keys depend on the type of the key.

=item req_attributes

Recevies the items extracted from the CSR as defined by the I<req_attributes>
activity parameter. The result is a hash where the key is the name of the
attribute and the value is the result of the extraction. See L<Extension Handling>

=item req_extensions

Same as I<req_attributes> for the I<req_extensions> paramter.

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

=head1 Extension Handling

The parameters I<req_attributes> and I<req_extensions> can be used to
define extra attributes to be extracted from the CSR.

Provide the OIDs/names to extract as a list, either directly as ArrayRef
or as comma/space seperated string. Named extensions are parsed as
defined below, unnamed extensions are returned as defined as "raw ASN1"
buffer.

Handling of named extensions depends on the Crypt::PKCS10 module so this
documentation might become outdated if the module changes!

=over

=item certificateTemplate (1.3.6.1.4.1.311.21.7)

Returns a hash with the keys I<templateID> (OID) and
I<templateMajorVersion>/I<templateMinorVersion> (INT) as defined by
Microsoft.

=item certificateTemplateName (1.3.6.1.4.1.311.20.2)

Returns the literal value given to this extension in the CSR.
In most cases this should be of type I<DirectoryString> so the value is
a literal string but the definition also allows this to be an undefined
ASN1 structure.

=item challengePassword (1.2.840.113549.1.9.7)

Returns the literal value of the challenge password attribute.

=back
