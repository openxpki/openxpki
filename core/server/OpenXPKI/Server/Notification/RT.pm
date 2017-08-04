## OpenXPKI::Server::Notification::RT
## SMTP Notifier using RT::Client::REST to connect to a
## RT RequestTracker ticket system
##
## Written 2013 by Oliver Welter for the OpenXPKI project
## (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Server::Notification::RT;
#use base qw( OpenXPKI::Server::Notification );

use strict;
use warnings;
use English;

use Data::Dumper;

use DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::FileUtils;
use OpenXPKI::Serialization::Simple;

use RT::Client::REST;
use RT::Client::REST::Ticket;

use Moose;

extends 'OpenXPKI::Server::Notification::Base';


has 'rt' => (
    is => 'ro',
    isa => 'Object',
    reader => '_rt',
    builder => '_init_transport',
    lazy => 1,
);

has 'template_dir' => (
    is  => 'ro',
    isa => 'Str',
    builder => '_init_template_dir',
    lazy => 1,
);

sub _init_transport {

    my $self = shift;

    ##! 8: 'creating transport'
    my $cfg = CTX('config')->get_hash( $self->config() . '.backend' );

    my $rt;

    eval {
        $rt = RT::Client::REST->new(
            server => $cfg->{server},
            timeout => $cfg->{timeout} || 30,
        );

        $rt->login(username => $cfg->{username}, password => $cfg->{password});
    };

    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_COULD_NOT_INSTANTIATE_CLIENT',
            params  => {
                'ERROR' => $EVAL_ERROR,
            },
        );
    }

    return $rt;
}

sub _init_template_dir {
    my $self = shift;
    my $template_dir = CTX('config')->get( $self->config().'.template.dir' );
    $template_dir .= '/' unless($template_dir =~ /\/$/);
    return $template_dir;
}



=head1 Functions
=head2 notify
see @OpenXPKI::Server::Notification::Base
=cut
sub notify {

    ##! 1: 'start'

    my $self = shift;
    my $args = shift;

    my $msg = $args->{MESSAGE};
    my $token = $args->{TOKEN};
    my $template_vars = $args->{VARS};

    my $msgconfig = $self->config().'.message.'.$msg;

    # Test if there is an entry for this kind of message
    my @handles = CTX('config')->get_keys( $msgconfig );

    ##! 8: 'Starting message ' . $msg

    ##! 16: 'Found handles ' . Dumper @handles

    ##! 32: 'Template vars: ' . Dumper $template_vars

    if (!@handles) {
        CTX('log')->system()->debug("No notifcations to send for $msgconfig");

        return 0;
    }

    # Walk through the handles
    QUEUE_HANDLE:
    foreach my $handle (@handles) {

        my $pi = $token->{$handle};

        ##! 16: 'Starting handle '.$handle.', PI: ' . Dumper $pi

        # We do the eval per handle
        eval {

            # Check if there is a ticket or the first action is open
            my $ticket;
            if ($pi->{ticket}) {
                $ticket = RT::Client::REST::Ticket->new(
                    rt => $self->_rt(),
                    id => $pi->{ticket},
                );
            } elsif (CTX('config')->get( "$msgconfig.$handle.0.action" ) ne "open") {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_NO_OPEN_TICKET',
                    params  => {
                        HANDLE => "$msgconfig.$handle",
                    }
               );
            }


            # The second level contains an array list for actions per channel
            my $size = CTX('config')->get_size( "$msgconfig.$handle" );
            for (my $i=0; $i<$size;$i++) {

                my $cfg = CTX('config')->get_hash( "$msgconfig.$handle.$i" );

                my $action = $cfg->{action};
                if (!$action) {
                    OpenXPKI::Exception->throw(
                        message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_NO_ACTIOn',
                        params  => {
                            HANDLE => "$msgconfig.$handle.$i",
                        }
                    );
                }

                delete $cfg->{action};
                ##! 16: 'next action ' . $action
                ##! 32: 'Config ' . Dumper $cfg
                if ($action eq "open") {
                    if ($ticket) {
                        OpenXPKI::Exception->throw(
                            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_OPEN_ON_EXISTING_TICKET',
                            params  => {
                                HANDLE => $msgconfig.$handle,
                            }
                        );
                    }
                    $ticket = $self->_rt_open({ CFG => $cfg, VARS => $template_vars });

                    $self->_set_flags({ TICKET => $ticket, CFG => $cfg } );

                    ##! 16: 'Initial open - new ticket id: ' . $ticket->id
                    $pi->{ticket} = $ticket->id;
                }


                if ($action eq "comment" || $action eq "correspond") {

                    if (!$cfg->{template}) {
                        OpenXPKI::Exception->throw(
                            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_MISSING_TEMPLATE',
                            params  => {
                                HANDLE => $msgconfig.$handle.$i,
                                ACTION => $action,
                            }
                        );
                    }

                    my $text = $self->_render_template_file( $self->template_dir().$cfg->{template}.'.txt', $template_vars );
                    ##! 16: 'rendering message template ' . $cfg->{template}
                    delete $cfg->{template};

                    # it is fine to have a template returning an empty value
                    if ($text) {
                        ##! 32: "$action with text $text"
                        $ticket->$action( message => $text );
                        $self->_set_flags({ TICKET => $ticket, CFG => $cfg } );
                    }

                }

                # Used to update fields without a comment and set custom fields
                elsif ($action eq "update") {
                    $self->_set_flags({ TICKET => $ticket, CFG => $cfg } );

                    # Check for custom fields - this is anything which is left now in the cfg hash
                    # TODO: This needs testing against a customized RT!
                    foreach my $key (keys %{$cfg}) {
                        my $val =  $self->_render_template( $cfg->{$key}, $template_vars );
                        ##! 32: "Adding custom field $key => $val "
                        $ticket->cf( $key => $val ) if($val);
                    }
                }

                # Shortcut for setting the status to resolved
                elsif ($action eq "close") {
                    ##! 32: 'Closing ticket '
                    $ticket->status( 'resolved' );
                }

                $ticket->store();

            } # end action loop

        };

        $token->{$handle} = $pi;

        if ($EVAL_ERROR) {
            CTX('log')->system()->error('RT action failed on ticket ' . $pi->{ticket} . ' with ' .  $EVAL_ERROR);

        }
    } # end handle

    return $token;

}
sub _cleanup {

}


sub _rt_open {

    ##! 1: 'start'

    my $self = shift;
    my $args = shift;
    my $cfg  = $args->{CFG};
    my $vars  = $args->{VARS};

    ##! 16: 'Template vars: ' . Dumper $vars

    # render the subject
    my $subject = $self->_render_template($cfg->{subject}, $vars);
    ##! 32: 'render the subject ' . $subject

    # Create a new ticket:
    my $ticket = RT::Client::REST::Ticket->new(
        rt => $self->_rt(),
        queue => $cfg->{queue} || 'General',
        owner => $cfg->{owner} || 'nobody',
        subject => $subject || 'PKI Request',
    );

    # for whatever reason you must first store the ticket before you can set the requestor
    if ($cfg->{template}) {
        my $text = $self->_render_template_file( $self->template_dir().$cfg->{template}.'.txt', $vars );
        $ticket->store(text => $text);
    } else {
        $ticket->store();
    }

    ##! 8: "Created a new ticket, ID " . $ticket->id

    # Add the requestor
    my $rcpt = $self->_render_template($cfg->{to}, $vars);
    ##! 32: 'Add the requestor ' . $rcpt
    $ticket->requestors ( [ $rcpt ] );

    ##! 32: 'Adding cc '
    my @ccrcpt;
    @ccrcpt = split(/,/, $cfg->{cc}) if ($cfg->{cc});
    foreach my $cc (@ccrcpt) {
        my $rcpt = $self->_render_template( $cc, $vars );
        ##! 32: 'New cc rcpt: ' . $cc . ' -> ' . $rcpt
        $ticket->add_cc( $rcpt ) if ($rcpt);
    }

    # Store again
    $ticket->store();

    CTX('log')->system()->info('Opening new RT ticket - id ' . $ticket->id);


    ##! 32: 'Ticket ' . Dumper $ticket

    ##! 1: 'end'
    return $ticket;

}

sub _set_flags {

    my $self = shift;
    my $args = shift;

    my $cfg  = $args->{CFG};
    my $ticket = $args->{TICKET};

    # Set priority and status before commenting
    if ($cfg->{priority}) {
        ##! 32: 'Set new priority: ' . $cfg->{priority}
        $ticket->priority( $cfg->{priority} );
        delete $cfg->{priority};
    }

    if ($cfg->{status}) {
        ##! 32: 'Set new status: ' . $cfg->{status}
        $ticket->status( $cfg->{status} );
        delete $cfg->{status};
    }


    return;
}


1;
