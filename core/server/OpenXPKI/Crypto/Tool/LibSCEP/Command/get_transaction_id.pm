## OpenXPKI::Crypto::Tool::LibSCEP::Command::get_transaction_id
## Written 2015-2018 by Gideon Knocke and Martin Bartosch for the OpenXPKI project
## (C) Copyright 2015-2018 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::LibSCEP::Command::get_transaction_id;

use strict;
use warnings;
use English;

use Class::Std;

use OpenXPKI::Debug;
use Crypt::LibSCEP;

my %scep_handle_of :ATTR;

sub START {
    my ($self, $ident, $arg_ref) = @_;
    $scep_handle_of{$ident} = $arg_ref->{SCEP_HANDLE};
}

sub get_result
{
    my $self = shift;
    my $ident = ident $self;

    my $transid;
    eval {
        $transid =  $scep_handle_of{$ident}->get_transaction_id;
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }
    ##! 16: 'transaction id: ' . $transid
    return $transid;
}

sub cleanup {

    my $self = shift;
    my $ident = ident $self;

}

1;

__END__

=head1 Name

OpenXPKI::Crypto::Tool::LibSCEP::Command::get_transaction_id

=head1 Description

This function takes a SCEP handle and returns a string that
represents the transaction ID in hex.
