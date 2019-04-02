## OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## Refactoring by Oliver Welter 2013 for the OpenXPKI project
## (C) Copyright 2005-2013 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain;

use Data::Dumper;
use OpenXPKI::Debug;
use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);
use English;
use OpenXPKI::FileUtils;
use OpenXPKI::Crypt::X509;

sub get_command
{
    my $self = shift;

    ## check parameters
    if (not $self->{PKCS7})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_GET_CHAIN_MISSING_PKCS7");
    }

    ## build the command

    my $command  = "pkcs7 -print_certs";
    $command .= " -inform PEM";
    $command .= " -in ".$self->write_temp_file( $self->{PKCS7} );
    $command .= " -out ".$self->get_outfile();

    return [ $command ];
}

sub hide_output
{
    return 0;
}

## please notice that key_usage means usage of the engine's key
sub key_usage
{
    my $self = shift;
    return 0;
}

sub get_result
{
    my $self = shift;

    my $fu = OpenXPKI::FileUtils->new();
    my $result = $fu->read_file ($self->get_outfile());

    my @extra_certs = ($result =~ m{ ( -----BEGIN\ [\w\s]*CERTIFICATE----- [^-]+ -----END\ [\w\s]*CERTIFICATE----- ) }gmsx);

    if ($self->{NOSORT}) {
        return \@extra_certs;
    }

    my $byIdentifier = {};
    my $bySubject = {};
    my $byKeyId = {};
    my $issuersByKeyId = {};
    my $issuersBySubject = {};

    while (my $pem = shift @extra_certs) {
        ##! 64: 'Next cert ' . $pem
        my $cert = OpenXPKI::Crypt::X509->new( $pem );
        my $id = $cert->get_cert_identifier();
        ##! 32: 'Next cert id ' . $id
        $byIdentifier->{ $id } = $cert ;
        $bySubject->{ $cert->get_subject } = $id;
        $byKeyId->{ $cert->get_subject_key_id } = $id;

        # issuer lists
        $issuersByKeyId->{ $cert->get_authority_key_id } = 1 if ($cert->get_authority_key_id);
        $issuersBySubject->{ $cert->get_issuer } = 1;
    }

    my %entity;
    map { $entity{ $bySubject->{$_} } = 1 unless($issuersBySubject->{$_}); } keys %{$bySubject};
    map { $entity{ $byKeyId->{$_} } = 1 unless($issuersByKeyId->{$_}); } keys %{$byKeyId};

    my @entity_id = keys %entity;
    ##! 32: 'Entity ' . Dumper \%entity
    if (scalar @entity_id != 1) {
      OpenXPKI::Exception->throw(
            message => 'Unable to determine entity in PCSK7 get_chain command'
        );
    }

    my $cert_id = shift @entity_id;
    ##! 16: 'Entity identifier ' . $cert_id
    my $cert = $byIdentifier->{$cert_id};

    if ($self->{NOCHAIN}) {
        return $cert->pem;
    }

    # Start with the entity and try to find the next issuer
    my $MAX_DEPTH = 16;
    my @chain;
    while ($cert && $MAX_DEPTH--) {

        push @chain, $cert->pem;

        if ($cert->is_selfsigned()) {
            ##! 16: 'Found self-signed'
            last;
        }

        my $aki = $cert->get_authority_key_id;
        my $id;
        if (!$aki || !$byKeyId->{$aki}) {
            ##! 32: 'Lookup using subject '  . $cert->get_issuer
            $id = $bySubject->{ $cert->get_issuer } || '';
        } else {
            ##! 32: 'Lookup using AKI ' . $aki
            $id = $byKeyId->{$aki};
        }
        $cert = $byIdentifier->{ $id };

    }


    ##! 32: 'Chain : ' . Dumper @chain
    if (! scalar @chain ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_BACKEND_OPENSSL_COMMAND_PKCS7_GET_CHAIN_COULD_NOT_CREATE_CHAIN',
        );
    }
    return \@chain;

}

1;

__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain

=head1 Functions

=head2 get_command

=over

=item * PKCS7 (a signature)

=item * NOCHAIN

=item * NOSORT

=back

=head2 hide_output

returns false (chain verification is not a secret)

=head2 key_usage

returns false

=head2 get_result

Returns an array ref holding the PEM-encoded certificates where the
first item is the entity certificate followed by the issuers in order.
Certificates from the bundle that are not required to build the chain are
not part of the result.

If NOCHAIN is set, returns only the entity as string.

If NOSORT is set, all certificates are returned as extraced from the
bundle without any additional sorting or filtering applied.


