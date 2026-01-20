package OpenXPKI::Exception;
use strict;
use warnings;

# Core modules
use Scalar::Util qw(blessed);

# CPAN modules
use Log::Log4perl;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context;
use OpenXPKI::i18n qw( i18nGettext );
use OpenXPKI::Log4perl;

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
    # Error while executing a command
    'OpenXPKI::Exception::InvalidConfig' => {
        isa => 'OpenXPKI::Exception',
    },
);

Log::Log4perl->wrapper_register(__PACKAGE__); # make Log4perl step up to the next call frame

my $log4perl_logger;

sub full_message {
    my ($self) = @_;

    # create cached value
    if (not exists $self->{full_message}) {
        my $params = $self->params; # yes, we modify them as a side-effect. old code relies on this.

        # add child errors to ERRVAL
        my @errval = exists $params->{ERRVAL} ? $params->{ERRVAL} : ();
        if (ref $self->{children} eq 'ARRAY') {
            foreach my $child ($self->{children}->@*) {
                push @errval, "$child" if $child; # stringify exceptions, skip empty arrays
            }
        }
        $params->{ERRVAL} = join ' ', @errval if @errval;

        # enforce __NAME__ scheme for "params"
        foreach my $key (sort keys $params->%*) {
            my $value = delete $params->{$key};
            $key =~s/^_*/__/;
            $key =~s/_*$/__/;
            $params->{$key} = $value;
        }

        # translate message
        $self->{full_message} = OpenXPKI::i18n::i18nGettext($self->{message});

        # append all "params" if NO translation took place
        if ($self->{full_message} eq $self->{message} and scalar keys $params->%*) {
            $self->{full_message}.= '; ' . $self->__format_params($params);
        }
    }

    ##! 1: "exception thrown: $msg"
    return $self->{full_message};
}

sub message_code {
    my $self = shift;
    return $self->{message};
}

sub throw {
    my $proto = shift;

    $proto->rethrow if ref $proto;

    # lazy mode - message string given as single argument
    my %args;
    if (scalar @_ == 1) {
        %args = (message => shift);
    } else {
        %args = (@_);
    }

    # If a given error is an OpenXPKI::Exception we just rethrow it
    if (blessed $args{error} and $args{error}->isa('OpenXPKI::Exception')) {
        ##! 32: 'rethrow existing exception'
        $args{error}->rethrow;
    }

    my %exception_args = %args;
    delete $exception_args{log};

    my $self = $proto->new(%exception_args);

    # log exception unless "log => undef" or Log4perl is not initialized
    if (
        not (exists $args{log} and not defined $args{log}) # no active suppression
        and Log::Log4perl->initialized
    ) {
        my $message = $args{log}->{message} || $self->full_message;
        my $facility = $args{log}->{facility};
        my $priority = $args{log}->{priority} || 'error';
        my $log;

        # append fields from subclass exceptions
        my $fields = $self->field_hash;
        for (keys $fields->%*) {
            delete $fields->{$_} unless defined $fields->{$_};
        }
        delete $fields->{params};       # remove some fields that are already
        delete $fields->{children};     # handled in full_message()
        delete $fields->{__is_logged};
        if (scalar keys $fields->%*) {
            $message = sprintf '%s (%s)', $message, $self->__format_params($fields);
        }

        # actual logging
        eval {
            # Server with CTX('log')
            if (OpenXPKI::Server::Context::hascontext('log')) {
                $facility ||= 'system';
                $log = OpenXPKI::Server::Context::CTX('log')->$facility;
            } else {
                $log = OpenXPKI::Log4perl->get_logger(
                    $facility
                    ? ($ENV{OPENXPKI_MOJO}
                        # Mojolicious client
                        ? $facility
                        # Server without CTX or legacy client
                        : "openxpki.$facility") # $facility is only used by server code
                    : ()
                );
            }
            $log->$priority( $message );
            $self->{__is_logged} = 1;
        };
    }
    die $self;
}

sub __format_params {
    my ($self, $params) = @_;

    my $max_item_length = 50;
    my $params_formatted =
        join ", ",
        map {
            my $val = $params->{$_};
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
        sort keys $params->%*;

    return $params_formatted;
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
