## OpenXPKI::Crypto::Tool::CreateJavaKeystore::Command::create_keystore.pm
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::CreateJavaKeystore::Command::create_keystore;

use strict;
use warnings;

use Class::Std;

use OpenXPKI::Debug;
use OpenXPKI::FileUtils;
use Data::Dumper;
use English;

my %fu_of       :ATTR; # a FileUtils instance
my %outfile_of  :ATTR;
my %tmp_of      :ATTR;
my %pkcs8_of    :ATTR;
my %password_of :ATTR;
my %certs_of    :ATTR;
my %engine_of   :ATTR;

sub START {
    my ($self, $ident, $arg_ref) = @_;

    $fu_of      {$ident} = OpenXPKI::FileUtils->new();
    # the PKCS#8 (DER), unencrypted
    $pkcs8_of   {$ident} = $arg_ref->{PKCS8};
    # the password for the key in the store
    $password_of{$ident} = $arg_ref->{PASSWORD};
    # an arrayref of DER-encoded certificates
    $certs_of   {$ident} = $arg_ref->{CERTIFICATES};
    $tmp_of     {$ident} = $arg_ref->{TMP};
}

sub get_command {
    ##! 1: 'start'
    my $self  = shift;
    my $ident = ident $self;
    
    my @certs;
    my @cert_filenames;
    eval {
        @certs = @{$certs_of{$ident}};
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_MAKEJAVAKEYSTORE_COMMAND_CREATE_KEYSTORE_COULD_NOT_GET_CERTIFICATE_ARRAY',
        );
    }
    foreach my $cert (@certs) {
        push @cert_filenames, $fu_of{$ident}->get_safe_tmpfile({
            'TMP' => $tmp_of{$ident},
        });
        ##! 16: 'filename for certificate: ' . $cert_filenames[-1]
        $fu_of{$ident}->write_file({
            FILENAME => $cert_filenames[-1],
            CONTENT  => $cert,
            FORCE    => 1,
        });
    }
    my $certfiles = '-cert ';
    $certfiles .= join ' -cert ', @cert_filenames;
    ##! 16: 'certfiles: ' . $certfiles

    $outfile_of{$ident} = $fu_of{$ident}->get_safe_tmpfile({
        'TMP' => $tmp_of{$ident},
    });
    
    my $stdin_data = 'keystore='  . $outfile_of{$ident}  . "\n";
    $stdin_data   .= 'storepass=' . $password_of{$ident} . "\n";
    $stdin_data   .= 'keypass='   . $password_of{$ident} . "\n";
    $stdin_data   .= "key=key:\n" . $pkcs8_of{$ident}    . "\n";

    ##! 1: 'end' 
    return {
        COMMAND => [ $certfiles . ' -' ],
        PARAMS  => [
            {
                TYPE => 'STDIN',
                DATA => $stdin_data,
            },
        ],
    };
}

sub hide_output
{
    return 1;
}

sub key_usage
{
    return 0;
}

sub cleanup
{
    return 1;
}

sub get_result
{
    ##! 1: 'start'
    my $self   = shift;
    my $ident  = ident $self;
    return $fu_of{$ident}->read_file($outfile_of{$ident});
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::CreateJavaKeystore::Command::create_keystore

=head1 Functions

=head2 get_command

=over

=item * PKCS8
=item * CERTIFICATES
=item * STOREKEYPASS

=back

=head2 hide_output

returns 0

=head2 key_usage

returns 0

=head2 get_result

Returns the Java keystore data for the given input
