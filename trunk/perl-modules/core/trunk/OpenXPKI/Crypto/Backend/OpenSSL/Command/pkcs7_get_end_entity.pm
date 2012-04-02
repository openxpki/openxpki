## OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_end_entity
## Written 2012 by Oliver Welter for the OpenXPKI project
## Based on OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_end_entity;

use OpenXPKI::Debug;
use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);
use English;
use Data::Dumper;
use OpenXPKI::FileUtils;
use OpenXPKI::DN;
use Encode;

sub get_command
{
    my $self = shift;

    ## compensate missing parameters

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
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_pkcs7_get_end_entity_MISSING_PKCS7");
    }

    ## prepare data
    $self->write_file (FILENAME => $self->{PKCS7FILE},
                       CONTENT  => $self->{PKCS7},
	               FORCE    => 1);

    ## build the command

    my $command  = "pkcs7 -print_certs";
    $command .= " -text";
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
        ##! 16: 'cert: ' . $cert
        my ($subject, $issuer) = ($cert, $cert);
        $subject =~ s{ .* ^ \s+ Subject:\ ([^\n]*)\n.*}{$1}xms;
        $subject = __convert_subject($subject);

        ##! 16: 'subject: ' . Dumper $subject
        $issuer  =~ s{ .* ^ \s+ Issuer:\ ([^\n]*)\n.*}{$1}xms;
        $issuer  = __convert_subject($issuer);

        ##! 16: 'issuer: ' . Dumper $issuer

        $cert    =~ s/^.*\n-----BEGIN/-----BEGIN/s;
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
    
    # Now unset all items of certsBySubject where the subject is listes in @issuers
    
    foreach my $issuer (@issuers) {
        ##! 16: "Remove issuer " . $issuer        
        delete( $certsBySubject{$issuer} ) if ($certsBySubject{$issuer});        
    }
    
    # Hopefully we have only one remaining now    
    my @subjectsRemaining = keys %certsBySubject; 
     if ( scalar @subjectsRemaining != 1 ) {
        ##! 2: "Too many remaining certs " . Dumper ( @subjectsRemaining )          
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_GET_END_ENTITY_UNABLE_TOO_DETECT_CORRECT_END_ENTITY_CERTIFICATE',
        );
     } 
     
     return $certsBySubject{ shift @subjectsRemaining }->{CERT};
     
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

OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_end_entity

Useful to extract the end entity certificate from a pkcs7 which 
contains only a certificate with its chain. The contained certificates
MUST all be part of the chain, the end entity is the one whoes subject
is not a signer in the contained bundle.

=head1 Functions

=head2 get_command

=over

=item * PKCS7 (a signature)

=item * ENGINE_USAGE

=back

=head2 hide_output

returns false 

=head2 key_usage

returns false

=head2 get_result

Returns the PEM-encoded certificate of the end entity.
