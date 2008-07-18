## OpenXPKI::Crypto::Tool::SCEP::Command::get_message_type
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::SCEP::Command::get_message_type;

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

sub START {
    my ($self, $ident, $arg_ref) = @_;
    ##! 16: 'arg_ref: ' . Dumper($arg_ref)
    $fu_of{$ident} = OpenXPKI::FileUtils->new();
    $tmp_of{$ident} = $arg_ref->{TMP};
    $pkcs7_of{$ident} = $arg_ref->{PKCS7};
}

sub get_command {
    my $self = shift;
    my $ident = ident $self;
    
    my $command = ' -print_msgtype -noout -inform DER ';
    
    my $in_filename = $fu_of{$ident}->get_safe_tmpfile({
        'TMP' => $tmp_of{$ident},
    });
    $outfile_of{$ident} = $fu_of{$ident}->get_safe_tmpfile({
        'TMP' => $tmp_of{$ident},
    });
    ##! 16: 'content: ' . Dumper $pkcs7_of{$ident}
    $fu_of{$ident}->write_file({
        FILENAME => $in_filename,
        CONTENT  => $pkcs7_of{$ident},
        FORCE    => 1,
    });
    ##! 16: 'stat: ' . Dumper(stat $in_filename)
   
    $command .= '-in ' . $in_filename;
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

    my $message_type = $fu_of{$ident}->read_file($outfile_of{$ident});
    chomp $message_type;
    $message_type =~ /([a-zA-z]+) \(([0-9]{1,2})\)/;
    my $message_type_name = $1;
    my $message_type_code = $2;

    my %return_ref = (
        MESSAGE_TYPE_NAME => $message_type_name,
        MESSAGE_TYPE_CODE => $message_type_code,
    );
    ##! 64: 'return_ref: ' . Dumper(\%return_ref)

    return \%return_ref;
}

sub cleanup {
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::SCEP::Command::message_type

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

returns the extracted SCEP message type as a hash with the name
and the code given in the keys MESSAGE_TYPE_NAME / MESSAGE_TYPE_CODE.
