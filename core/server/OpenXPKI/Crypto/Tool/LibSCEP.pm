package OpenXPKI::Crypto::Tool::LibSCEP;

use base qw( OpenXPKI::Crypto::Toolkit );

use strict;
use warnings;
use English;

use Class::Std;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use Data::Dumper;

# skip shell init from Toolkit as we dont need it
sub __init_shell { }

sub __init_command {
    ##! 16: 'start'
    my $self = shift;

    $self->get_command_params()->{ENGINE} = $self->get_engine();

    ##! 16: 'end'
}

sub command {
    ##! 1: "start"
    my $self = shift;
    my $arg_ref = shift;

    my $cmd  = 'OpenXPKI::Crypto::Tool::LibSCEP::Command::' . $arg_ref->{COMMAND};
    delete $arg_ref->{COMMAND};

    eval "require $cmd";
    if ($EVAL_ERROR ne '') {
        OpenXPKI::Exception->throw(
            message  => 'I18N_OPENXPKI_TOOLKIT_COMMAND_REQUIRE_FAILED',
            params   => {'EVAL_ERROR' => $EVAL_ERROR},
        );
    }
    ##! 2: "Command: $cmd"

    my $ret = eval {
        my $cmd_ref = $cmd->new({
            %{ $self->get_command_params() },
            %{$arg_ref},
            });
        my $result = $cmd_ref->get_result();
        return $result;
    };

    if (my $exc = OpenXPKI::Exception->caught())
    {
        ##! 16: 'exception: ' . Dumper $exc
        ##! 16: 'eval_error: ' . $EVAL_ERROR
        OpenXPKI::Exception->throw (
            message  => "I18N_OPENXPKI_TOOLKIT_COMMAND_FAILED",
            params   => {"COMMAND" => $cmd},
            children => [ $exc ]);
    } elsif ($EVAL_ERROR ne '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_TOOLKIT_COMMAND_EVAL_ERROR',
            params => {
                'EVAL_ERROR' => $EVAL_ERROR,
            },
        );
    } else {
        ##! 4: "end"
        return $ret;
    }
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::LibSCEP

=head1 Description

Child class of OpenXPKI::Crypto::Toolkit for LibSCEP
