## OpenXPKI::Crypto::Tool::SCEP::Command::get_pkcs10.pm
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::SCEP::Command::get_pkcs10;

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
   
    my $command = " -print_req -noout -passin env:pwd -keyfile $keyfile -in $in_filename -out $outfile_of{$ident} "; 
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

    my $pkcs10 = $fu_of{$ident}->read_file($outfile_of{$ident});

    return $pkcs10;
}

sub cleanup {
    $ENV{pwd} = '';
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::SCEP::Command::get_pkcs10

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

Gets the PKCS#10 CSR from a CertReq SCEP message.
