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
my %pkcs12_of    :ATTR;
my %password_of :ATTR;
my %password_out_of :ATTR;

sub START {
    my ($self, $ident, $arg_ref) = @_;

    # FileUtils and tmp
    $fu_of      {$ident} = OpenXPKI::FileUtils->new();
    $tmp_of     {$ident} = $arg_ref->{TMP};

    # the PKCS#12,  encrypted with PASS
    $pkcs12_of   {$ident} = $arg_ref->{PKCS12};
    $password_of{$ident} = $arg_ref->{PASSWD};
    if ($arg_ref->{OUT_PASSWD}) {
        $password_out_of{$ident} = $arg_ref->{OUT_PASSWD};
    } else {
        $password_out_of{$ident} = $arg_ref->{PASSWD};
    }

    if (length $password_out_of{$ident} < 6) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_JAVAKEYSTORE_COMMAND_CREATE_KEYSTORE_PASSWORD_TOO_SHORT",
        );
    }

}

sub get_command {
    ##! 1: 'start'
    my $self  = shift;
    my $ident = ident $self;

    $outfile_of{$ident} = $fu_of{$ident}->get_safe_tmpfile({
        'TMP' => $tmp_of{$ident},
    });

    my $pkcs12 = $fu_of{$ident}->get_safe_tmpfile({
        'TMP' => $tmp_of{$ident},
    });
    $fu_of{$ident}->write_file({
        FILENAME => $pkcs12,
        CONTENT  => $pkcs12_of{$ident},
        FORCE    => 1,
    });

    #$self->set_env ("jkspass" => $self->{PASSWD});
    #$self->set_env ("p12pass" => $self->{PASSWD});

    $ENV{jkspass} = $password_out_of{$ident};
    $ENV{p12pass} = $password_of{$ident};

    my $command = "-importkeystore ";
    $command .= " -srcstoretype PKCS12 -srcstorepass:env p12pass -srckeystore " . $pkcs12;
    $command .= " -deststoretype JKS -storepass:env jkspass -destkeystore ". $outfile_of{$ident};

    return [ $command ];

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
    delete $ENV{jkspass};
    delete $ENV{p12pass};
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
