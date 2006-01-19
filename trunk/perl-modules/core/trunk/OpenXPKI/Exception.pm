## OpenXPKI::Exception
##
## Written by Michael Bell for the OpenXPKI project
## Copyright (C) 2005 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::Exception;

use OpenXPKI qw (i18nGettext);

use Exception::Class (
    "OpenXPKI::Exception" =>
    {
        fields => [ "errno", "child", "params" ],
    }
);

sub full_message
{
    my ($self) = @_;

    ## respect child errors
    if (ref $self->{child})
    {
        $self->{params}->{"ERRVAL"} = $self->{child}->as_string();
        $self->{params}->{"ERRNO"}  = $self->{child}->get_errno()
            if ($self->{errno} and $self->{child}->get_errno());
    } elsif ($self->{child}) {
        $self->{params}->{"ERRVAL"} = $self->{child};
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
    my $msg = i18nGettext ($self->{message}, %{$self->{params}});
    if ($msg eq $self->{message})
    {
        $msg = join ", ", ($msg, %{$self->{params}});
    }
    print STDERR "$msg\n";
    return $msg;
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
