## OpenXPKI::Crypto::Tool::LibSCEP::Command::get_message_type
## Written 2015-2018 by Gideon Knocke and Martin Bartosch for the OpenXPKI project
## (C) Copyright 2015-2018 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::LibSCEP::Command::get_message_type;

use strict;
use warnings;
use English;

use Class::Std;

use OpenXPKI::Debug;
use Crypt::LibSCEP;

my %scep_handle_of   :ATTR;

sub START {
    my ($self, $ident, $arg_ref) = @_;
    $scep_handle_of{$ident} = $arg_ref->{SCEP_HANDLE};
}

sub get_result {
    my $self = shift;
    my $ident = ident $self;

    my $message_type;
    eval {
        $message_type = $scep_handle_of{$ident}->get_message_type;
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }
    ##! 16: 'message_type: ' . $message_type
    return $message_type;
}

sub cleanup {
    my $self = shift;
    my $ident = ident $self;

}

1;
__END__


=head1 Name

OpenXPKI::Crypto::Tool::LibSCEP::Command::get_message_type

=head1 Description

This function takes a SCEP handle and returns a string indicating
the message type.
