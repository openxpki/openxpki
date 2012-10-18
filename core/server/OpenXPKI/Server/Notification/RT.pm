## OpenXPKI::Server::Notification::RT
## Request Tracker (RT) notifier
##
## Written 2007 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project

package OpenXPKI::Server::Notification::RT;
use base qw( OpenXPKI::Server::Notification );

use strict;
use warnings;
use English;

use Class::Std;
use RT::Client::REST;

use Data::Dumper;

use OpenXPKI::Debug;
use OpenXPKI::Exception;

my %url_of       :ATTR; # URL of the RT instance
my %username_of  :ATTR; # RT username
my %password_of  :ATTR; # RT password
my %timeout_of   :ATTR; # RT timeout
my %rt_of        :ATTR; # RT client instance
        
sub START {
    ##! 1: 'start'
    my $self  = shift;
    my $ident = shift;

    # set attributes from configuration
    $url_of{$ident}      = $self->__get_backend_config_value('url');
    $username_of{$ident} = $self->__get_backend_config_value('username');
    $password_of{$ident} = $self->__get_backend_config_value('password');
    $timeout_of{$ident}  = $self->__get_backend_config_value('timeout');

    # instantiate the RT client
    $self->__instantiate_rt_client();

    ##! 1: 'end'
    return 1; 
}

sub open {
    ##! 1: 'start'
    my $self       = shift;
    my $ident      = ident $self;
    my $arg_ref    = shift;
    my $subject    = $arg_ref->{SUBJECT};
    my $queue      = $arg_ref->{QUEUE};
    my $requestors = $arg_ref->{REQUESTORS};

    my $rt_id;

    $self->__login();
    ##! 4: 'successfully logged in to the RT system'

    foreach my $requestor (@{ $requestors }) {
        if ($requestor !~ m{ \A .+ \@ .+ \z }xms) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_REQUESTOR_IS_NOT_AN_EMAIL_ADDRESS',
                params  => {
                    REQUESTOR => $requestor,
                },
            );
        }
    }
    eval {
        $rt_id = $rt_of{$ident}->create(
            type => 'ticket',
            set  => {
                'subject'    => $subject,
                'queue'      => $queue,
                'requestors' => $requestors,
            },
        );
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_COULD_NOT_CREATE_TICKET',
            params  => {
                ERROR => $EVAL_ERROR,
            },
        ); 
    }
    ##! 4: 'successfully created RT ticket ' . $rt_id

    ##! 1: 'end'
    return $rt_id;
}

sub ticket_exists {
    ##! 1: 'start'
    my $self   = shift;
    my $ident  = ident $self;

    $self->__login();
    ##! 4: 'successfully logged in to the RT system'

    my $ticket_id = shift;
    my $ticket;
    eval {
        $ticket = $rt_of{$ident}->show(type => 'ticket', id => $ticket_id);
    };
    ##! 16: 'ticket: ' . Dumper $ticket
    return (defined $ticket);
}

sub correspond {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;
    my $content = $arg_ref->{CONTENT};
    my $ticket  = $arg_ref->{TICKET};

    $self->__login();
    ##! 4: 'successfully logged in to the RT system'

    my ($cc, $bcc, $body) = $self->__parse_content($content);
    eval {
        $rt_of{$ident}->correspond(
            ticket_id => $ticket,
            message   => $body,
            cc        => $cc,
            bcc       => $bcc,
        );
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_COULD_NOT_SET_VALUE_IN_TICKET',
            params  => {
                ERROR  => $EVAL_ERROR,
                TICKET => $ticket,
            },
        ); 
    }
    ##! 1: 'end'
    return;
}

sub comment {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;
    my $content = $arg_ref->{CONTENT};
    my $ticket  = $arg_ref->{TICKET};

    $self->__login();
    ##! 4: 'successfully logged in to the RT system'

    my ($cc, $bcc, $body) = $self->__parse_content($content);
    eval {
        $rt_of{$ident}->comment(
            ticket_id => $ticket,
            message   => $body,
            cc        => $cc,
            bcc       => $bcc,
        );
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_COULD_NOT_SET_VALUE_IN_TICKET',
            params  => {
                ERROR  => $EVAL_ERROR,
                TICKET => $ticket,
            },
        ); 
    }
    ##! 1: 'end'
    return;
}

sub set_value {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;
    my $field   = $arg_ref->{FIELD};
    my $value   = $arg_ref->{VALUE};
    my $ticket  = $arg_ref->{TICKET};

    $self->__login();
    ##! 4: 'successfully logged in to the RT system'

    # FIXME - custom fields always fail, looks like an RT bug
    eval {
        $rt_of{$ident}->edit(
            type => 'ticket',
            id   => $ticket,
            set  => {
                $field => $value,
            },
        );
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_COULD_NOT_SET_VALUE_IN_TICKET',
            params  => {
                ERROR  => $EVAL_ERROR,
                TICKET => $ticket,
            },
        ); 
    }

    ##! 1: 'end'
    return;
}

sub link_tickets {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;
    my $type    = $arg_ref->{TYPE};
    my $link    = $arg_ref->{LINK};
    my $ticket  = $arg_ref->{TICKET};

    $self->__login();
    ##! 4: 'successfully logged in to the RT system'

    eval {
        $rt_of{$ident}->link_tickets(
            src       => $ticket,
            dst       => $link,
            link_type => $type,
        );
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_COULD_NOT_LINK_TICKETS',
            params  => {
                ERROR  => $EVAL_ERROR,
                TICKET => $ticket,
                TYPE   => $type,
                LINK   => $link,
            },
        ); 
    }

    ##! 1: 'end'
    return;
}

sub close {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;
    my $ticket  = $arg_ref->{TICKET};

    $self->__login();
    ##! 4: 'successfully logged in to the RT system'

    eval {
        $rt_of{$ident}->edit(
            type => 'ticket',
            id   => $ticket,
            set  => {
                'status' => 'resolved',
            },
        );
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_COULD_NOT_CLOSE_TICKET',
            params  => {
                ERROR  => $EVAL_ERROR,
                TICKET => $ticket,
            },
        ); 
    }
    ##! 1: 'end'
    return;
}

sub get_ticket_info {
    ##! 1: 'start'
    my $self      = shift;
    my $ident     = ident $self;
    my $ticket    = shift;
    ##! 16: 'ticket: ' . $ticket

    $self->__login();
    ##! 4: 'successfully logged in to the RT system'

    my $info;
    eval {
        $info = $rt_of{$ident}->show(
            type => 'ticket',
            id   => $ticket,
        );
    };
    if (my $err = $EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_SHOW_FAILED',
            params  => {
                'ERROR' => $err,
            },
        );
    }
    ##! 16: 'info: ' . Dumper $info

    return $info;
}

sub get_url_for_ticket {
    ##! 1: 'start'
    my $self      = shift;
    my $ident     = ident $self;
    my $ticket    = shift;

    return $url_of{$ident} . '/Ticket/Display.html?id=' . $ticket;
}

sub __pre_notification {
    ##! 1: 'start'
    my $self      = shift;
    my $ident     = ident $self;

    ##! 1: 'end'
    return 1;
}

sub __instantiate_rt_client :PRIVATE {
    ##! 1: 'start'
    my $self  = shift;
    my $ident = ident $self;

    # try to instantiate the RT client
    eval {
        $rt_of{$ident} = RT::Client::REST->new(
            server  => $url_of{$ident},
            timeout => $timeout_of{$ident},
        );
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_COULD_NOT_INSTANTIATE_CLIENT',
            params  => {
                'ERROR' => $EVAL_ERROR,
            },
        );
    }
    ##! 1: 'end'
    return 1;
}

sub __login :PRIVATE {
    ##! 1: 'start'
    my $self  = shift;
    my $ident = ident $self;

    # try to login to RT
    eval {
        $rt_of{$ident}->login(
            username => $username_of{$ident},
            password => $password_of{$ident},
        );
    };
    # TODO - figure out how to use try/catch correctly, so that we
    # also get the error message from RT::Client::REST
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_COULD_NOT_LOGIN',
            params  => {
                'ERROR' => $EVAL_ERROR,
            },
        );
    }
    ##! 1: 'end'
    return 1;
}

sub __parse_content {
    ##! 1: 'start'
    my $self   = shift;
    my $content = shift;

    my @content = split(/\n/, $content);
    my @cc  = ();
    my @bcc = ();
    my $body = '';
    if ($content[0] =~ /:/) {
        # the content contains a header, parse it
        my $end_of_header_index = 0;
       PARSE_HEADER:
        for (my $i = 0; $i < scalar @content; $i++) {
            my $line = $content[$i];
            if ($line eq '') {
                $end_of_header_index = $i;
                last PARSE_HEADER;
            }
            if ($line =~ m{ \A Cc: (.*) \z}xms) {
                push @cc, $1;
            }
            if ($line =~ m{ \A Bcc: (.*) \z}xms) {
                push @bcc, $1;
            }
        }
        # create body
        for (my $i = $end_of_header_index; $i < scalar @content; $i++) {
            $body .= $content[$i] . "\n";
        }
    }
    else {
        # the complete content is the body.
        $body = $content;
    }
    ##! 1: 'end'
    return (\@cc, \@bcc, $body);
}

1;

__END__

=head1 Name

OpenXPKI::Server::Notification::RT - Notification via Request Tracker (RT)

=head1 Description

This class implements a notifier that sends out notification via
Best Practial Solution's RT (Request Tracker) software.

=head1 Functions

=over

=item * START

Is the constructor. Sets the RT specific attributes (URL, username,
password, timeout) from the XML configuration.

=item * open

Opens a new ticket at the RT instance. Returns the ticket ID of
the freshly created ticket.

=item * correspond

Sends correspondence to the ticket owner and possibly other people
using RT.

=item * comment

Comment on a RT ticket

=item * set_value

Sets the value of an RT ticket field. Currently does not seem
to work with custom fields.

=item * link_tickets

Can be used to link two tickets to each other.

=item * close

Closes a given RT ticket.

=item * get_url_for_ticket

Returns the URL for a given ticket.

=item * __pre_notification

Called by the parent notify() before a notification takes place.
Calls __instantiate_rt_client() and __login() to prepare for the
actual notification.

=item * __instantiate_rt_client

Tries to instantiate the RT::Client::REST object.

=item * __login

Tries to login to the RT instance.

=item * __parse_content

Used by both comment and correspond to parse the given content into
a header and body part, extracting Cc and Bcc addresses for the
calls.

=back
