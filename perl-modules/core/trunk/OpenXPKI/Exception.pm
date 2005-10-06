## OpenXPKI::Exception
## Copyright (C) 2004-2005 Michael Bell
## $Revision: 9 $

use strict;
use warnings;

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
    print STDERR i18nGettext ($self->{message}, %{$self->{params}})."\n";
    return i18nGettext ($self->{message}, %{$self->{params}});
}

sub get_errno
{
    ## the normal name errno is not possible
    ## errno results in a redefinition warning
    my $self = shift;
    if ($self->{errno})
    {
        return $self->{errno};
    } else {
        if ($self->{child} and ref $self->{child})
        {
            return $self->{child}->errno();
        } else {
            return;
        }
    }
}

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

Please note that FILENAME will be extended to __FILENAME__.
