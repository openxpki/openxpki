## OpenXPKI::Crypto::Tool::SCEP::Command::get_getcert_serial.pm
## Written 2013 by Oliver Welter for the OpenXPKI project
## (C) Copyright 2013 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::SCEP::Command::get_getcrl_issuer_serial;

use strict;
use warnings;

use Class::Std;

use OpenXPKI::Debug;
use OpenXPKI::FileUtils;
use Data::Dumper;

my %fu_of      :ATTR; # a FileUtils instance
my %outfile_of :ATTR;
my %tmp_of     :ATTR;
my %pkcs7_of   :ATTR;
my %engine_of  :ATTR;

sub START {
    my ($self, $ident, $arg_ref) = @_;

    $fu_of    {$ident} = OpenXPKI::FileUtils->new();
    $engine_of{$ident} = $arg_ref->{ENGINE};
    $tmp_of   {$ident} = $arg_ref->{TMP};
    $pkcs7_of {$ident} = $arg_ref->{PKCS7};
}

sub get_command {
    my $self  = shift;
    my $ident = ident $self;

    # keyfile, signcert, passin
    if (! defined $engine_of{$ident}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_SCEP_COMMAND_CREATE_PENDING_REPLY_NO_ENGINE',
        );
    }
    ##! 64: 'engine: ' . Dumper($engine_of{$ident})
    my $keyfile  = $engine_of{$ident}->get_keyfile();
    if (! defined $keyfile || $keyfile eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_SCEP_COMMAND_CREATE_PENDING_REPLY_KEYFILE_MISSING',
        );
    }
    $ENV{pwd}    = $engine_of{$ident}->get_passwd();

    my $in_filename = $fu_of{$ident}->get_safe_tmpfile({
        'TMP' => $tmp_of{$ident},
    });
    $outfile_of{$ident} = $fu_of{$ident}->get_safe_tmpfile({
        'TMP' => $tmp_of{$ident},
    });
    $fu_of{$ident}->write_file({
        FILENAME => $in_filename,
        CONTENT  => $pkcs7_of{$ident},
        FORCE    => 1,
    });

    my $command = " -text -inform DER -noout -passin env:pwd -keyfile $keyfile -in $in_filename -out $outfile_of{$ident} ";
    return $command;
}

sub hide_output
{
    return 0;
}

sub key_usage
{
    return 1;
}

sub get_result
{
    my $self = shift;
    my $ident = ident $self;

    my $crl_info = $fu_of{$ident}->read_file($outfile_of{$ident});

    # this is a verbose output that looks like
    # Issuer and Serial:
    #  Issuer: CN=Root CA,OU=Test CA,DC=OpenXPKI,DC=ORG
    #  Serial: 0x03

    my @crl_info = split /\n/, $crl_info;

    while ((shift @crl_info) !~ /Issuer and Serial:/) {
        if (scalar(@crl_info) < 2) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_TOOL_SCEP_COMMAND_GET_CRL_ISSUER_SERIAL_FAILED',
            );
        }
    }

    $crl_info[0] =~ /Issuer:\s+(.+)\z/;
    my $issuer = $1;
    $crl_info[1] =~ /Serial:\s+(.+)\z/;
    my $serial= $1;

    if (!$issuer || !$serial) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_SCEP_COMMAND_GET_CRL_ISSUER_SERIAL_FAILED',
        );
    }

    return { ISSUER => $issuer, SERIAL => $serial };
}

sub cleanup {

    my $self = shift;
    my $ident = ident $self;

    $ENV{pwd} = '';
    $fu_of{$ident}->cleanup();

}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::SCEP::Command::get_getcert_serial

=head1 Functions

=head2 get_command

=over

=item * PKCS7

=back

=head2 hide_output

returns 0

=head2 key_usage

returns 0

=head2 get_result

Gets the certificate serial number requested in a GetCert SCEP message.
