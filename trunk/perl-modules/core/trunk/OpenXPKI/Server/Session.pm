## OpenXPKI::Server::Session.pm 
##
## Written 2006 by Michael Bell for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::Server::Session;

use English;
use OpenXPKI::Exception;

## switch of IP checks
use CGI::Session qw/-ip-match/;

## constructor and destructor stuff

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = shift;

    if (exists $keys->{LIFETIME} and $keys->{LIFETIME} > 0)
    {
        $self->{LIFETIME} = $keys->{LIFETIME};
    }
    else
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_SESSION_NEW_MISSING_LIFETIME");
    }

    if (not exists $keys->{DIRECTORY})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_SESSION_NEW_MISSING_DIRECTORY");
    }
    if (not -d $keys->{DIRECTORY})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_SESSION_NEW_DIRECTORY_DOES_NOT_EXIST",
            params  => {DIRECTORY => $keys->{DIRECTORY}});
    }
    $self->{DIRECTORY} = $keys->{DIRECTORY};

    if (exists $keys->{ID})
    {
        $self->{ID} = $keys->{ID};
        $self->{session} = new CGI::Session(
                                   undef,
                                   $self->{ID},
                                   {Directory=>$self->{DIRECTORY}});
        if (not $self->{session} or
            $self->{ID} ne $self->{session}->id())
        {
            $self->{session}->delete() if ($self->{session});
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_SESSION_NEW_LOAD_SESSION_FAILED",
                params  => {ID        => $self->{ID},
                            DIRECTORY => $self->{DIRECTORY}});
        }
    }
    else
    {
        $self->{session} = new CGI::Session(
                                   undef,
                                   undef,
                                   {Directory=>$self->{DIRECTORY}});
        if (not $self->{session})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_SESSION_NEW_CREATE_SESSION_FAILED",
                params  => {ID        => $self->{ID},
                            DIRECTORY => $self->{DIRECTORY}});
        }
        $self->{session}->param ("status" => "invalid");
    }
    $self->{session}->expire($self->{LIFETIME});
    $self->{session}->flush();

    return $self;
}

sub delete
{
    my $self = shift;
    $self->{session}->delete();
    delete $self->{session};
}

sub DESTROY
{
    my $self = shift;
    if (exists $self->{session} and ref $self->{session})
    {
        $self->{session}->expire($self->{LIFETIME});
        $self->{session}->flush();
    }
}

## authentication support / status of session

sub start_authentication
{
    my $self = shift;
    $self->{session}->param ("status" => "auth");
    $self->{session}->flush();
}

sub make_valid
{
    my $self = shift;
    $self->{session}->param ("status" => "valid");
    $self->{session}->flush();
}

sub is_valid
{
    my $self = shift;
    if ($self->{session}->param ("status") eq "valid")
    {
        return 1;
    } else {
        return 0;
    }
}

sub set_challenge
{
    my $self = shift;
    $self->{session}->param ("challenge" => shift);
    $self->{session}->flush();
}

sub get_challenge
{
    my $self = shift;
    $self->{session}->param ("challenge");
}

## fully public getter and setter function

sub set_user
{
    my $self = shift;
    $self->{session}->param ("user" => shift);
    $self->{session}->flush();
}

sub get_user
{
    my $self = shift;
    return $self->{session}->param ("user");
}

sub set_role
{
    my $self = shift;
    $self->{session}->param ("role" => shift);
    $self->{session}->flush();
}

sub get_role
{
    my $self = shift;
    return $self->{session}->param ("role");
}

sub set_pki_realm
{
    my $self = shift;
    $self->{session}->param ("pki_realm" => shift);
    $self->{session}->flush();
}

sub get_pki_realm
{
    my $self = shift;
    return $self->{session}->param ("pki_realm");
}

sub set_authentication_stack
{
    my $self = shift;
    $self->{session}->param ("authentication_stack" => shift);
    $self->{session}->flush();
}

sub get_authentication_stack
{
    my $self = shift;
    return $self->{session}->param ("authentication_stack");
}

sub set_language
{
    my $self = shift;
    $self->{session}->param ("language" => shift);
    $self->{session}->flush();
}

sub get_language
{
    my $self = shift;
    return $self->{session}->param ("language");
}

sub get_id
{
    my $self = shift;
    return $self->{session}->id();
}

1;
__END__

=head1 Description

This module implements the coomplete session mechanism for the
OpenXPKI core code. This include some mechanisms to support the
authentication phase which means that it is possible to operate
a session in a mode which is not valid.

=head1 Function

=head2 Constructor/Destructor

=head3 new

This function creates a new or load an already existing session.
It supports the following parameters:

=over

=item * LIFETIME [seconds]

=item * DIRECTORY [path to "cookie" area]

=item * ID [session ID]

=back

=head3 delete

This function is called without any argument and simply removes
the session. This is required on failed authentications. Please
note that the behaviour of an object refrence after a call to
delete is completeley undefined. Simply drop any references
to a session object after you call delete on it.

=head2 Status Management (authentication support)

=head3 start_authentication

sets the status of the session to authentication mode.

=head3 make_valid

sets the status of the session to valid.

=head3 is_valid

returns 1 if it is a valid session and 0 if the session is not valid.

=head3 set_challenge

sets a challenge string. This is useful for authentication tasks
if the session is not valid.

=head3 get_challenge

returns a challenge string if such a string was set in the past.

=head2 Set/Get functions

=over

=item * set_user

=item * get_user

=item * set_role

=item * get_role

=item * set_pki_realm

=item * get_pki_realm

=item * get_id

=back
