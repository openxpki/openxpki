## OpenXPKI::Crypto::Tool::PKCS7::Command::is_not_self_signed.pm
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::PKCS7::Command::is_not_self_signed;

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
    $pkcs7_of {$ident} = $arg_ref->{PKCS7};
    $tmp_of   {$ident} = $arg_ref->{TMP};
}

sub get_command {
    my $self  = shift;
    my $ident = ident $self;
    
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
   
    my $command = " verify -verbose -in $in_filename"; 
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
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::PKCS7::Command::is_not_self_signed

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

Verifies the signature on a PKCS#7 message. Returns 1 if the signature is
not self-signed, throws an exception if the signature is self-signed.
Also throws an exception if the signature is invalid.
