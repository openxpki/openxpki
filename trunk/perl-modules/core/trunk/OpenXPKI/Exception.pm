## OpenXPKI::Exception
##
## Written by Michael Bell for the OpenXPKI project
## Copyright (C) 2005 by The OpenXPKI Project

package OpenXPKI::Exception;

use strict;
use warnings;
#use diagnostics;
use utf8;

use OpenXPKI::Debug;
use OpenXPKI::Server::Context;
use Log::Log4perl qw( get_logger );

use OpenXPKI::i18n qw( i18nGettext );
use Exception::Class (
    "OpenXPKI::Exception" =>
    {
        fields => [ "children", "params" ],
    }
);

my $log4perl_logger;

sub full_message
{
    my ($self) = @_;

    ## respect child errors
    if (ref $self->{children})
    {
        foreach my $child (@{$self->{children}})
        {
            next if (not $child); ## empty array
            $self->{params}->{"ERRVAL"} .= " " if ($self->{params}->{"ERRVAL"});
            if (ref $child)
            {
                $self->{params}->{"ERRVAL"} .= $child->as_string();
            } else {
                $self->{params}->{"ERRVAL"} = $self->{child};
            }
        }
    }

    ## enforce __NAME__ scheme
    foreach my $param (keys %{$self->{params}})
    {
        my $value = $self->{params}->{$param};
        delete $self->{params}->{$param};
        $param =~s/^_*/__/;
        $param =~s/_*$/__/;
        $self->{params}->{$param} = $value;
    }

    ## put together and translate message
    my $msg = OpenXPKI::i18n::i18nGettext ($self->{message}, %{$self->{params}});
    if ($msg eq $self->{message})
    {
        $msg = join ", ", ($msg, %{$self->{params}});
    }
    ## this is only for debugging of OpenXPKI::Exception
    ## and creates a lot of noise
    ## print STDERR "$msg\n";

    ##! 1: "exception thrown: $msg"

    return $msg;
}

sub throw {
    my $proto = shift;

    $proto->rethrow if ref $proto;

    my %args = ( @_ );
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


    my %logger_args = (
	MESSAGE     => 'Exception: ' . $self->full_message(%args),
	FACILITY    => 'system',
	PRIORITY    => 'debug',
	CALLERLEVEL => 1,
	);

    
    if (exists $args{log}) {
	# log => undef means: do not log at all
	if (defined $args{log}) {
	    if (exists $args{log}->{message}) {
		$logger_args{MESSAGE} = $args{log}->{message};
	    }
	    
	    if (exists $args{log}->{facility}) {
		$logger_args{FACILITY} = $args{log}->{facility};
	    }
	    
	    if (exists $args{log}->{priority}) {
		$logger_args{PRIORITY} = $args{log}->{priority};
	    }
	    

	    # logger object was explicitly specified
	    if (exists $args{log}->{logger}
		&& (ref $args{log}->{logger} eq 'OpenXPKI::Server::Log')) {
		
		$args{log}->{logger}->log(
		    %logger_args,
		    );
		
		delete $args{log};
	    } else {
		# no logger specified, instantiate one
		OpenXPKI::Server::Context::CTX('log')->log(
		    %logger_args,
		    );
	    }
	} else {
	    # no OpenXPKI logger specified, do not log at all
	    ##! 1: 'suppressed log message: ' . $logger_args{MESSAGE}
	}
    } else {
	# exceptions get logged by default
	my $logger;
	eval {
	    $logger = OpenXPKI::Server::Context::CTX('log');
	};

	if (defined $logger) {
	    # we have an OpenXPKI logger available
	    $logger->log(
		%logger_args,
		);
	} else {
	    # no system logger found, falling back to Log4perl
	    $log4perl_logger ||= get_logger('openxpki.system');
	    $log4perl_logger->debug($logger_args{MESSAGE});
	}
    }

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

#sub get_errno
#{
#    ## the normal name errno is not possible
#    ## errno results in a redefinition warning
#    my $self = shift;
#    if ($self->{errno})
#    {
#        return $self->{errno};
#    } else {
#        if ($self->{child} and ref $self->{child})
#        {
#            return $self->{child}->errno();
#        } else {
#            return;
#        }
#    }
#}

1;
__END__

=head1 Name

OpenXPKI::Exception - central exception class of OpenXPKI.

=head1 Description

This is the basic exception class of OpenXPKI.

=head1 Intended use

OpenXPKI::Exception->throw (message => "I18N_OPENXPKI_FAILED",
                            child   => $other_exception,
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
