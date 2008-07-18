## OpenXPKI::Crypto::Tool::SCEP::Command::create_error_reply.pm
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::SCEP::Command::create_error_reply;

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
my %error_of   :ATTR;

sub START {
    my ($self, $ident, $arg_ref) = @_;

    $fu_of    {$ident} = OpenXPKI::FileUtils->new();
    $engine_of{$ident} = $arg_ref->{ENGINE};
    $tmp_of   {$ident} = $arg_ref->{TMP};
    $pkcs7_of {$ident} = $arg_ref->{PKCS7};
    $error_of {$ident} = $arg_ref->{'ERROR_CODE'};
}

sub get_command {
    my $self  = shift;
    my $ident = ident $self;
    
    # keyfile, signcert, passin
    if (! defined $engine_of{$ident}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_SCEP_COMMAND_CREATE_ERROR_REPLY_NO_ENGINE',
        );
    }
    ##! 64: 'engine: ' . Dumper($engine_of{$ident})
    my $keyfile  = $engine_of{$ident}->get_keyfile();
    if (! defined $keyfile || $keyfile eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_SCEP_COMMAND_CREATE_ERROR_REPLY_KEYFILE_MISSING',
        );
    }
    my $certfile = $engine_of{$ident}->get_certfile();
    if (! defined $certfile || $certfile eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_SCEP_COMMAND_CREATE_ERROR_REPLY_CERTFILE_MISSING',
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

    if ($error_of{$ident} !~ m{ badAlg | badMessageCheck | badRequest | badTime | badCertId }xms) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_SCEP_COMMAND_CREATE_ERROR_REPLY_INVALID_ERROR_CODE',
            params => {
                'ERROR_CODE' => $error_of{$ident},
            }
        );
    }
    my $command = " -new -passin env:pwd -signcert $certfile -msgtype CertRep -status FAILURE -failinfo $error_of{$ident} -keyfile $keyfile -inform DER -in $in_filename -outform DER -out $outfile_of{$ident} "; 
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

    my $error_reply = $fu_of{$ident}->read_file($outfile_of{$ident});

    return $error_reply;
}

sub cleanup {
    $ENV{pwd} = '';
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::SCEP::Command::create_error_reply

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

Creates an SCEP ERROR reply with a given error code.
