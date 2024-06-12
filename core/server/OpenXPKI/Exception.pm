package OpenXPKI::Exception;

use strict;
use warnings;

use Scalar::Util qw(blessed);

use OpenXPKI::Debug;
use OpenXPKI::Server::Context;
use Log::Log4perl;

use OpenXPKI::i18n qw( i18nGettext );
use Exception::Class (
    'OpenXPKI::Exception' => {
        fields => [ 'children', 'params', '__is_logged' ],
    },
    # Validation failed on workflow or api input field
    'OpenXPKI::Exception::InputValidator' => {
        isa => 'OpenXPKI::Exception',
        fields => [ 'errors', 'action' ],
    },
    # Authentication request was not successful
    'OpenXPKI::Exception::Authentication' => {
        isa => 'OpenXPKI::Exception',
        fields => [ 'stack', 'error', 'authinfo' ],
    },
    # Timeout while waiting for a socket or external process
    'OpenXPKI::Exception::Timeout' => {
        isa => 'OpenXPKI::Exception',
        fields => [ 'error', 'command', 'timeout' ],
    },
    # Error during socket communication
    'OpenXPKI::Exception::Socket' => {
        isa => 'OpenXPKI::Exception',
        fields => [ 'error', 'socket' ],
    },
    # Error while executing a command
    'OpenXPKI::Exception::Command' => {
        isa => 'OpenXPKI::Exception',
        fields => [ 'error' ],
    },
    # Error while executing a command
    'OpenXPKI::Exception::WorkflowPickupFailed' => {
        isa => 'OpenXPKI::Exception',
    },
);

my $log4perl_logger;

sub full_message {
    my ($self) = @_;

    ## respect child errors
    if (ref $self->{children}) {
        foreach my $child (@{$self->{children}}) {
            next if (not $child); ## empty array
            $self->{params}->{"ERRVAL"} .= " " if ($self->{params}->{"ERRVAL"});
            if (ref $child) {
                $self->{params}->{"ERRVAL"} .= $child->as_string();
            }
            else {
                $self->{params}->{"ERRVAL"} = $self->{child};
            }
        }
    }

    ## enforce __NAME__ scheme
    foreach my $param (sort keys %{$self->{params}}) {
        my $value = $self->{params}->{$param};
        delete $self->{params}->{$param};
        $param =~s/^_*/__/;
        $param =~s/_*$/__/;
        $self->{params}->{$param} = $value;
    }

    ## put together and translate message
    my $msg = OpenXPKI::i18n::i18nGettext($self->{message} );

    # append all parameters if message was not translated
    if ($msg eq $self->{message} and scalar keys %{$self->{params}}) {
        my $max_item_length = 50;
        my $params_formatted =
            join ", ",
            map {
                my $val = $self->{params}->{$_};
                my $formatted;
                if (not defined $val) {
                    $formatted = "EMPTY";
                }
                elsif (ref $val eq 'ARRAY') {
                    # special hack for the validator field list which is an array of hashes
                    if ($_ eq 'FIELDS') {
                        $formatted = join(",", map { ref $_ ? $_->{name} : $_ } @{$val});
                    } else {
                        my $items = join(",", @$val);
                        $items = substr($items, 0, $max_item_length-3) . "..." if length $items > $max_item_length;
                        $formatted = "Array($items)";
                    }
                }
                elsif (ref $val eq 'HASH') {
                    my $items = join ",", map { "$_=".($val->{$_} // '') } sort keys %$val;
                    $items = substr($items, 0, $max_item_length-3) . "..." if length $items > $max_item_length;
                    $formatted = "Hash($items)";
                }
                else {
                    $formatted = $val;
                }
                sprintf "%s => %s", $_, $formatted;
            }
            sort keys %{$self->{params}};

        $msg = "$msg; $params_formatted";
    }
    ## this is only for debugging of OpenXPKI::Exception
    ## and creates a lot of noise
    ## print STDERR "$msg\n";

    ##! 1: "exception thrown: $msg"

    return $msg;
}

sub message_code {
    my $self = shift;
    return $self->{message};
}

sub throw {
    my $proto = shift;

    $proto->rethrow if ref $proto;

    # lazy mode -  message string given as single argument
    my %args = (@_);
    if (scalar @_ == 1) {
        %args = (message => shift );
    } else {
        %args           = (@_);
    }

    # If an error is given and the error is an OpenXPKI::Exception
    # we do NOT create a new exeption but rethrow it
    if ($args{error} && blessed($args{error}) && $args{error}->isa('OpenXPKI::Exception')) {
        ##! 32: 'rethrow existing exception'
        $args{error}->rethrow();
    }

    my %exception_args = %args;
    delete $exception_args{log};

    #    # This is a bit of an evil hack until Exception::Class supports
    #    # turning off stack traces, see
    #    # http://rt.cpan.org/Ticket/Display.html?id=26489
    #    # for a bug report and patch
    #    # It fakes the Devel::StackTrace calls that are used in
    #    # Exception::Class to be nearly empty, which massively speeds up
    #    # Exception throwing
    #    local *Devel::StackTrace::new
    #        = *OpenXPKI::Exception::__fake_stacktrace_new;
    #    local *Devel::StackTrace::frame
    #        = *OpenXPKI::Exception::__fake_stacktrace_frame;

    my $self = $proto->new(%exception_args);

    # suppress logging if "log => undef" or L4p is not initialized
    if ((exists $args{log} && !defined $args{log}) || !Log::Log4perl->initialized()) {
        die $self;
    }

    my $message = $args{log}->{message} || $self->full_message(%args);
    my $facility = $args{log}->{facility} || 'system';
    my $priority = $args{log}->{priority} || 'error';

    eval {
        # this hides this subroutine from the call stack to get the real
        # location of the exception
        local $Log::Log4perl::caller_depth =
              $Log::Log4perl::caller_depth + 2;

        if (OpenXPKI::Server::Context::hascontext('log')) {
            my $log = OpenXPKI::Server::Context::CTX('log');
            $log->$facility()->$priority( $message );
            $self->{__is_logged} = 1;
        } else {
            my $log = Log::Log4perl->get_logger('openxpki.'. $facility );
            $log->$priority( $message );
            $self->{__is_logged} = 1;
        }
    };

    die $self;
}

sub __fake_stacktrace_new {
    ##! 16: 'fake_stacktrace_new called'
    my $that  = shift;
    my $class = ref($that) || $that;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub __fake_stacktrace_frame {
    ##! 16: 'fake_stacktrace_frame called'
    return 0;
}

1;
__END__

=head1 Name

OpenXPKI::Exception - central exception class of OpenXPKI.

=head1 Description

This is the basic exception class of OpenXPKI.

=head1 Intended use

OpenXPKI::Exception->throw (message => "I18N_OPENXPKI_FAILED",
                            children  => [$other_exception],#opt.
                            params  => {FILENAME => $file});

if (my $exc = OpenXPKI::Exception->caught())
{
    ## handle it or throw again
    my $errno  = $exc->errno();
    my $errval = $exc->as_string();
    OpenXPKI::Exception->throw (message => ..., child => $exc, params => {...});
} else {
    $EVAL_ERROR->rethrow();
}

Please note that FILENAME will be extended to __FILENAME__. If you want
to send a specific errorcode to the caller then you can specify errno
directly like message, child or params.

=head1 New Functions

usually all functions from Exception::Class will be used. Nevertheless
one function will be overloaded and on new function will be specified
to support other modules with errorcodes if one is available.

=head2 full_message

This function is used to build the new errormessages conforming to
the specifications of OpenXPKI. This means in the first line the
specification of i18n.

=head2 message_code

returns the untranslated and unmodified i18n-message-code

=head2 Fields

returns the names of the available parameters (message, errno, child, params).

=head2 errno

errno returns the errorcode if available.

=head2 child

returns the exception object of the child if this is
a nested exception.

=head2 params

returns a hash reference with name and value pairs of the parameters for
the error message (i18nGettext).
