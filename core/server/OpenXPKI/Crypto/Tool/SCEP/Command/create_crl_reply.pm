
package OpenXPKI::Crypto::Tool::SCEP::Command::create_crl_reply;

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
my %crl_of    :ATTR;
my %engine_of  :ATTR;
my %enc_alg_of :ATTR;
my %hash_alg_of  :ATTR;

sub START {
    my ($self, $ident, $arg_ref) = @_;

    $fu_of     {$ident} = OpenXPKI::FileUtils->new();
    $engine_of {$ident} = $arg_ref->{ENGINE};
    $tmp_of    {$ident} = $arg_ref->{TMP};
    $pkcs7_of  {$ident} = $arg_ref->{PKCS7};
    $crl_of   {$ident} = $arg_ref->{CRL};
    $enc_alg_of{$ident} = $arg_ref->{ENCRYPTION_ALG};
    $hash_alg_of {$ident} = $arg_ref->{HASH_ALG};

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
    my $certfile = $engine_of{$ident}->get_certfile();
    if (! defined $certfile || $certfile eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_SCEP_COMMAND_CREATE_PENDING_REPLY_CERTFILE_MISSING',
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
    my $crl_file = $fu_of{$ident}->get_safe_tmpfile({
        'TMP' => $tmp_of{$ident},
    });
    $fu_of{$ident}->write_file({
        FILENAME => $crl_file,
        CONTENT  => $crl_of{$ident},
        FORCE    => 1,
    });

    my $command = " -new -passin env:pwd -signcert $certfile -msgtype CertRep -status SUCCESS -keyfile $keyfile -inform DER -in $in_filename -outform DER -out $outfile_of{$ident} -crlfile $crl_file ";

    if ($enc_alg_of{$ident} eq 'DES') {
        # if the configured encryption algorithm is DES, append the
        # appropriate option. This is for example needed for
        # Netscreen devices
        $command .= " -des ";
    }

    if ($hash_alg_of{$ident}) {
        $command .= ' -'.$hash_alg_of{$ident};
    }
    return $command;
}

sub hide_output
{
    return 0;
}

sub key_usage
{
    return 0;
}

sub get_result
{
    my $self = shift;
    my $ident = ident $self;

    my $reply = $fu_of{$ident}->read_file($outfile_of{$ident});

    return $reply;
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

OpenXPKI::Crypto::Tool::SCEP::Command::create_certificate_reply

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

Creates an SCEP reply containing the issued certificate.
