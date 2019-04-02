
package OpenXPKI::Server::Workflow::Activity::Tools::ParseCertificate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use OpenXPKI::DN;
use OpenXPKI::Crypt::X509;
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

    my $pem = $self->param('pem');

    OpenXPKI::Exception->throw(
        message => 'No certificate data received'
    ) unless ($pem);

    my ($data) = $pem =~ m{(-----BEGIN ([\w\s]*)CERTIFICATE-----.*?-----END \2CERTIFICATE-----)}xms;

    OpenXPKI::Exception->throw(
        message => 'Data is not a PEM encoded certificate'
    ) unless ($data);

    my $subject_prefix = $self->param('subject_prefix') || 'cert_';

    # Cleanup any existing values
    $context->param({
        'cert_subject' => '',
        'cert_subject_key_identifier' => '',
        'cert_identifier' => '',
        'cert_issuer' => '',
        $subject_prefix.'subject_parts' => '',
#        $subject_prefix.'san_parts' => '',
        $subject_prefix.'subject_alt_name' => '',
    });

    my $x509 = OpenXPKI::Crypt::X509->new($data);

    my %hashed_dn;
    my $cert_subject = $x509->get_subject();

    if ($cert_subject) {
        my $dn = OpenXPKI::DN->new( $cert_subject );
        %hashed_dn = $dn->get_hashed_content();
        $param->{$subject_prefix.'subject_parts'} = $serializer->serialize( \%hashed_dn );
        $param->{cert_subject} = $dn->get_rfc_2253_dn();
        ##! 32: 'Subject DN ' . Dumper \%hashed_dn
    }

    $param->{notbefore} = $x509->get_notbefore('epoch');
    $param->{notafter} = $x509->get_notafter('epoch');
    $param->{serial} = $x509->get_serial();
    $param->{cert_subject_key_identifier} = $x509->get_subject_key_id();
    $param->{cert_issuer} = $x509->get_issuer();
    $param->{cert_identifier} = $x509->get_cert_identifier();

    my $san = $x509->get_subject_alt_name();
    $param->{$subject_prefix.'subject_alt_name'} = $serializer->serialize( $san ) if ($san);

    # TODO key params, san/subject parsing based on profile, extenstions

    ##! 64: 'Params to set ' . Dumper $param
    $context->param( $param );

    return 1;
}

1;

__END__


=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::ParseCertificate

=head1 Description

Take a PEM encoded certificate and extract information to the context.

=head1 Configuration

=head2 Activity Parameters

=over

=item pem

The PEM formatted certificate. If the input string consists of multiple
concatenated PEM blocks, the first one is used, the remainder discarded.

=item subject_prefix

Prefix for context output keys to write the subject information into
(cert_subject_parts, cert_san_parts, cert_subject_alt_name).
Default is I<cert_>.

=back

=head2 Context value to be written

Prefix for the subject parts can be changed by setting I<subject_prefix>.

=over

=item cert_subject

The extracted subject as string (comma seperated)

=item cert_identifier

The OpenXPKI identifier calculated from the certificate.

=item cert_issuer

The issuer dn as string.

=item cert_subject_key_identifier

The key identifier of the used public key, Hex with uppercased letters.
The format is identical to the return value of the API method
get_key_identifier_from_data and the format used in the certificates table.

=item notbefore / notafter

Validity dates of the certificate as epoch

=item serial

The serialnumber in integer notation

=item <prefix>_subject_parts

Contains the parsed DN as key-value pairs where the key
is the shortname of the component (e.g: OU) and the value is an array of
values found. Note that any component is an array even if it has only one
item.

=item <prefix>_subject_alt_name

All SAN items as nested array list. Each item of the
list is a two item array with name and value of one SAN item. The names
are given as required to build then openssl extension file (otherName,
email, DNS, dirName, URI, IP, RID).


=back
