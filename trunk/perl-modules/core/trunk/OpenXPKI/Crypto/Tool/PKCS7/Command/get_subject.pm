## OpenXPKI::Crypto::Tool::PKCS7::Command::get_subject.pm
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::PKCS7::Command::get_subject;

use strict;
use warnings;

use Class::Std;

use OpenXPKI::Debug;
use OpenXPKI::FileUtils;
use Data::Dumper;
use List::Util qw( first );

my %fu_of      :ATTR; # a FileUtils instance
my %outfile_of :ATTR;
my %tmp_of     :ATTR;
my %pkcs7_of   :ATTR;
my %engine_of  :ATTR;
my %data_of    :ATTR;

sub START {
    my ($self, $ident, $arg_ref) = @_;

    $fu_of    {$ident} = OpenXPKI::FileUtils->new();
    $pkcs7_of {$ident} = $arg_ref->{PKCS7};
    $tmp_of   {$ident} = $arg_ref->{TMP};
    $data_of  {$ident} = $arg_ref->{DATA};
}

sub get_command {
    ##! 1: 'start'
    my $self  = shift;
    my $ident = ident $self;
    
    my $in_filename = $fu_of{$ident}->get_safe_tmpfile({
        'TMP' => $tmp_of{$ident},
    });
    $fu_of{$ident}->write_file({
        FILENAME => $in_filename,
        CONTENT  => $pkcs7_of{$ident},
        FORCE    => 1,
    });
    my $data_filename;
    if (defined $data_of{$ident}) {
        ##! 16: 'data defined'
        $data_filename = $fu_of{$ident}->get_safe_tmpfile({
            'TMP' => $tmp_of{$ident},
        });
        $fu_of{$ident}->write_file({
            FILENAME => $data_filename,
            CONTENT  => $data_of{$ident},
            FORCE    => 1,
        });
    }
   
    my $command = " verify -in $in_filename"; 
    if (defined $data_filename) {
        ##! 16: 'data_filename defined'
        $command .= " -data $data_filename";
    }
    ##! 1: 'end'
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

sub cleanup
{
    return 1;
}
sub get_result
{
    ##! 1: 'start'
    my $self   = shift;
    my $ident  = ident $self;
    my $result = shift;

    ##! 16: 'result: ' . $result
    my @lines = split(/\n/, $result);

    my $subject = first {$_ =~ /^depth:0.*subject:(.*)/} @lines;
    $subject =~ s/^depth:0.*subject://;

    return $subject;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::PKCS7::Command::get_subject

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

Returns the subject of the signer of a PKCS#7 message.
