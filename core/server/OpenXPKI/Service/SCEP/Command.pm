use strict;
use warnings;

package OpenXPKI::Service::SCEP::Command;

use base qw(OpenXPKI::Service::LibSCEP::Command);

sub START {
    my ($self, $ident, $arg_ref) = @_;
    ##! 1: "START"
    ##! 2: ref $self
    # only in Command.pm base class: get implementation
    if (ref $self eq 'OpenXPKI::Service::SCEP::Command') {
        ##! 4: Dumper $arg_ref
        $self->attach_impl($arg_ref);
    }
}


1;

__END__;
