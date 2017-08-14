## OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## Refactoring by Oliver Welter 2013 for the OpenXPKI project
## (C) Copyright 2005-2013 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain;

use OpenXPKI::Debug;
use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);
use English;
use Data::Dumper;
use OpenXPKI::FileUtils;
use OpenXPKI::DN;
use OpenXPKI::Crypto::X509;
use Encode;

sub get_command
{
    my $self = shift;

    $self->get_tmpfile ('PKCS7', 'OUT');

    my $engine = "";
    my $engine_usage = $self->{ENGINE}->get_engine_usage();
    $engine = $self->{ENGINE}->get_engine()
        if ($self->{ENGINE}->get_engine() and
            ($engine_usage =~ m{ ALWAYS }xms));

    ## check parameters
    if (not $self->{PKCS7})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_GET_CHAIN_MISSING_PKCS7");
    }

    ## prepare data
    $self->write_file (FILENAME => $self->{PKCS7FILE},
                       CONTENT  => $self->{PKCS7},
                   FORCE    => 1);

    ## build the command

    my $command  = "pkcs7 -print_certs";
    #$command .= " -text";
    $command .= " -inform PEM";
    $command .= " -in ".$self->{PKCS7FILE};
    $command .= " -out ".$self->{OUTFILE};

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
    my $pkcs7 = $fu->read_file ($self->{OUTFILE});

    # We want to have the end entity certificate, which we autodetect by looking for
    # the certificate whoes subject is not an issuer in the found list

    ##! 16: 'pkcs7: ' . $pkcs7
    ##! 2: "split certs"
    my %certsBySubject = ();
    my @issuers = ();
    my @parts = split /-----END CERTIFICATE-----\n\n/, $pkcs7;
    foreach my $cert (@parts)
    {
        $cert .= "-----END CERTIFICATE-----\n";
        $cert    =~ s/^.*\n-----BEGIN/-----BEGIN/s;
        my ($subject, $issuer);
        # Load the PEM into the x509 Object to parse it
        ##! 4: "determine the subject of the end entity cert"
        eval {
            my $x509 = $self->{XS}->get_object ({DATA => $cert, TYPE => "X509"});
            $subject = $self->{XS}->get_object_function ({
                           OBJECT   => $x509,
                           FUNCTION => "subject"});
            $issuer = $self->{XS}->get_object_function ({
                           OBJECT   => $x509,
                           FUNCTION => "issuer"});
            $self->{XS}->free_object ($x509);
        };
        ##! 8: 'Subject: ' . $subject
        ##! 8: 'Issuer: ' . $issuer

        if (exists $certsBySubject{$subject} &&
            $certsBySubject{$subject}->{ISSUER} ne $issuer &&
            $certsBySubject{$subject}->{CERT} ne $cert) {
            ##! 64: 'something funny is going on, the same certificate subject with different issuer or data is present'
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_GET_END_ENTITY_MULTIPLE_SAME_SUBJECTS_WITH_DIFFERENT_DATA',
            );
        }

        $certsBySubject{$subject}->{ISSUER} = $issuer;
        $certsBySubject{$subject}->{CERT}   = $cert;

        push @issuers, $issuer;

    }

    ##! 64: 'certs: ' . Dumper \%certsBySubject

    # Find subjects which are not issuers = entities

    my %entity =  map { $_ => 1 } keys %certsBySubject;

    # Now unset all items where the subject is listes in @issuers
    foreach my $issuer (@issuers) {
        ##! 16: "Remove issuer " . $issuer
        delete( $entity{$issuer} ) if ($entity{$issuer});
    }

    # Hopefully we have only one remaining now
    my @subjectsRemaining = keys %entity;
     if ( scalar @subjectsRemaining != 1 ) {
        ##! 2: "Too many remaining certs " . Dumper ( @subjectsRemaining )
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_GET_END_ENTITY_UNABLE_TOO_DETECT_CORRECT_END_ENTITY_CERTIFICATE',
        );
     }

    my $subject = shift @subjectsRemaining;

    # Requestor was just interessted in the entity
    if ($self->{NOCHAIN}) {
        ##! 8: 'entity only requested '
        ##! 32: 'Entity pem ' . $certsBySubject{$subject}->{CERT}
        return $certsBySubject{$subject}->{CERT};
    }

    # Start with the entity and build the chain
    ##! 16: 'entity subject: ' . $subject
    ##! 2: "create ordered cert list"
    my @chain;
    my $iterations = 0;
    my $MAX_CHAIN_LENGTH = 32;
    while (exists $certsBySubject{$subject} && $iterations < $MAX_CHAIN_LENGTH)
    {
        ##! 16: 'while for subject: ' . $subject
        push @chain, $certsBySubject{$subject}->{CERT};
        last if ($subject eq $certsBySubject{$subject}->{ISSUER});
        $subject = $certsBySubject{$subject}->{ISSUER};
        $iterations++;
    }
    ##! 2: "end"
    ##! 32: 'Chain : ' . Dumper @chain
    if (! scalar @chain ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_BACKEND_OPENSSL_COMMAND_PKCS7_GET_CHAIN_COULD_NOT_CREATE_CHAIN',
        );
    }
    return \@chain;

}

sub __convert_subject {
    ##! 1: 'start'
    my $subject = shift;
    $subject =~ s/, /,/g;

    while ($subject =~ /\\x[0-9A-F]{2}/) {
        ##! 64: 'subject still contains \x-escaped character, replacing'
        use bytes;
        $subject =~ s/\\x([0-9A-F]{2})/chr(hex($1))/e;
        no bytes;
        ##! 64: 'subject after replacement: ' . $subject
    }

    my $dn = OpenXPKI::DN->new($subject);
    $subject = $dn->get_x500_dn();

    ##! 1: 'end'
    return $subject;
}
1;

__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain

=head1 Functions

=head2 get_command

=over

=item * PKCS7 (a signature)

=back

=head2 hide_output

returns false (chain verification is not a secret)

=head2 key_usage

returns false

=head2 get_result

Returns the PEM-encoded certificates in the correct order which are
contained in the signature. The certificates are seperated by a blank
line.
