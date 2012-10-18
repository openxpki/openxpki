## OpenXPKI::Crypto::Tool::SCEP::Command::get_transaction_id
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::SCEP::Command::get_transaction_id;

use strict;
use warnings;

use Class::Std;

use OpenXPKI::Debug;
use Data::Dumper;

# OpenSSL::Command is used as there is no SCEP::Command ...
use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

my %fu_of :ATTR; # a FileUtils instance
my %outfile_of :ATTR;
my %tmp_of :ATTR;
my %pkcs7_of :ATTR;

sub START {
    my ($self, $ident, $arg_ref) = @_;
    $fu_of{$ident} = OpenXPKI::FileUtils->new();
    $tmp_of{$ident} = $arg_ref->{TMP};
    $pkcs7_of{$ident} = $arg_ref->{PKCS7};
}

sub get_command {
    my $self = shift;
    my $ident = ident $self;
    
    my $command = ' -print_transid -noout -inform DER ';
    
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
   
    $command .= '-in ' . $in_filename,
    $command .= ' -out ' . $outfile_of{$ident};

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

    my $trans_id = uc($fu_of{$ident}->read_file($outfile_of{$ident}));
    chomp $trans_id;
    ##! 16: "trans ID: $trans_id"
    $trans_id =~ m{ \A TRANSACTION\ ID=([A-F0-9]+) \z }xms;

    return $1;
}

sub cleanup {
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::SCEP::Command::get_transcation_id

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

returns the extracted SCEP transaction ID.
