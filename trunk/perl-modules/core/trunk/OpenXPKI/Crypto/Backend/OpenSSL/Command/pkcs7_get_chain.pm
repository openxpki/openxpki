## OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::pkcs7_get_chain;

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

    if (! defined $self->{SIGNER} && ! defined $self->{SIGNER_SUBJECT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_GET_CHAIN_MISSING_SIGNER_OR_SIGNER_SUBJECT");
    }
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
    ##! 16: 'pkcs7: ' . $pkcs7
    ##! 2: "split certs"
    my %certs = ();
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
        if (exists $certs{$subject} && 
            $certs{$subject}->{ISSUER} ne $issuer &&
            $certs{$subject}->{CERT} ne $cert) {
            ##! 64: 'something funny is going on, the same certificate subject with different issuer or data is present'
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_GET_CHAIN_MULTIPLE_SAME_SUBJECTS_WITH_DIFFERENT_DATA',
            );
        }
        $certs{$subject}->{ISSUER} = $issuer;
        $certs{$subject}->{CERT}   = $cert;
    }
    
    ##! 64: 'certs: ' . Dumper \%certs
    
    ##! 2: "order certs"
    my $subject = $self->{SIGNER_SUBJECT};
    ##! 16: 'SIGNER_SUBJECT: ' . $subject
    if (not $subject)
    {
        ##! 4: "determine the subject of the end entity cert"
        eval
        {
            my $x509 = $self->{XS}->get_object ({DATA => $self->{SIGNER},
                                                     TYPE => "X509"});
            $subject = $self->{XS}->get_object_function ({
                           OBJECT   => $x509,
                           FUNCTION => "subject"});
            $self->{XS}->free_object ($x509);
        };
        ##! 4: "eval finished"
        if (my $exc = OpenXPKI::Exception->caught())
        {
            ##! 8: "OpenXPKI exception detected"
            OpenXPKI::Exception->throw (
                message  => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_PKCS7_GET_CHAIN_WRONG_SIGNER",
                children => [ $exc ]);
        } elsif ($EVAL_ERROR) {
            ##! 8: "general exception detected"
            $EVAL_ERROR->rethrow();
        }
        $subject = encode_utf8($subject);
    }
    ##! 16: 'subject: ' . $subject
    ##! 2: "create ordered cert list"
    $pkcs7 = "";
    my $iterations = 0;
    my $MAX_CHAIN_LENGTH = 1000;
    while (exists $certs{$subject} && $iterations < $MAX_CHAIN_LENGTH)
    {
        ##! 16: 'while for subject: ' . $subject
        $pkcs7  .= $certs{$subject}->{CERT}."\n\n";
        last if ($subject eq $certs{$subject}->{ISSUER});
        $subject = $certs{$subject}->{ISSUER};
        $iterations++;
    }
    ##! 2: "end"
    ##! 16: 'pkcs7: ' . $pkcs7
    if ($pkcs7 eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_BACKEND_OPENSSL_COMMAND_PKCS7_GET_CHAIN_COULD_NOT_CREATE_CHAIN',
        );
    }
    return $pkcs7;
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

You must specify the SIGNER or the SIGNER_SUBJECT.

=over

=item * PKCS7 (a signature)

=item * ENGINE_USAGE

=item * SIGNER (the signer to find the chain's begin)

=item * SIGNER_SUBJECT (the subject of the signer's certificate)

=back

=head2 hide_output

returns false (chain verification is not a secret)

=head2 key_usage

returns false

=head2 get_result

Returns the PEM-encoded certificates in the correct order which are
contained in the signature. The certificates are seperated by a blank
line.
