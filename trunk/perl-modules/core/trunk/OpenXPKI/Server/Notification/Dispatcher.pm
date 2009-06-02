## OpenXPKI::Server::Notification::Dispatcher
##
## Written 2007 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project

package OpenXPKI::Server::Notification::Dispatcher;

use strict;
use warnings;
use English;

use Class::Std;

use Data::Dumper;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;

my %notifier_of :ATTR; # hashref of arrays of notifier objects by realm
        
sub START {
    ##! 2: 'start'
    my $self    = shift;
    my $ident   = shift;
    my $arg_ref = shift;
    my $cfg_id  = $arg_ref->{CONFIG_ID};

    my $config = CTX('xml_config');

    my $nr_of_realms = $config->get_xpath_count(
        XPATH     => 'pki_realm',
        CONFIG_ID => $cfg_id,
    );
    ##! 16: 'nr_of_realms: ' . $nr_of_realms

    # iterate over PKI realms
    for (my $i = 0; $i < $nr_of_realms; $i++) {
        my $pki_realm = $config->get_xpath(
            XPATH     => [ 'pki_realm', 'name' ],
            COUNTER   => [ $i         , 0      ],
            CONFIG_ID => $cfg_id,
        );
        ##! 16: 'pki_realm: ' . $pki_realm

	my @xpath   = ( 'pki_realm', 'common', 'notification' );
	my @counter = ( $i         , 0       , 0              );
        
        my $nr_of_notifiers = 0;
        eval {
            $nr_of_notifiers = $config->get_xpath_count(
                XPATH    => [ @xpath  , 'notifier' ],
                COUNTER  => [ @counter ],
                CONFIG_ID => $cfg_id,
            );
        };
        ##! 16: 'notifiers: ' . $nr_of_notifiers

        # iterate over notifiers	
        for (my $ii = 0; $ii < $nr_of_notifiers; $ii++) {
            my $notifier = $config->get_xpath(
                XPATH     => [ @xpath  , 'notifier' ],
                COUNTER   => [ @counter, $ii        ],
                CONFIG_ID => $cfg_id,
            );
            ##! 16: 'notifier: ' . $notifier
            my $notifier_type = $self->__get_notifier_type($notifier, $cfg_id);
            ##! 16: 'notifier_type: ' . $notifier_type
            my $notifier_obj;
            my $notifier_class = 'OpenXPKI::Server::Notification::'
                . $notifier_type;
            eval "require $notifier_class";
            if ($EVAL_ERROR) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_FAILED_TO_USE_NOTIFIER_CLASS',
                    params  => {
                        PKI_REALM => $pki_realm,
                        TYPE      => $notifier_type,
                        ERROR     => $EVAL_ERROR,
                    },
                    log     => {
                        logger   => CTX('log'),
                        priority => 'error',
                        facility => 'system',
                    },
                );

            }
            eval {
                $notifier_obj = $notifier_class->new({
                    CONFIG    => $config,
                    NAME      => $notifier,
                    PKI_REALM => $pki_realm,
                    CONFIG_ID => $cfg_id,
                });
            };
            if (my $exc = OpenXPKI::Exception->caught()) {
                OpenXPKI::Exception->throw(
                    message  => 'I18N_OPENXPKI_SERVER_NOTIFICATION_FAILED_TO_INSTANTIATE_NOTIFIER',
                    children => [ $exc ],
                    params   => {
                        PKI_REALM => $pki_realm,
                        TYPE      => $notifier_type, 
                        NAME      => $notifier,
                    },
                    log      => {
                        logger   => CTX('log'),
                        priority => 'error',
                        facility => 'system',
                    },
                );
            }
            elsif ($EVAL_ERROR) {
                OpenXPKI::Exception->throw(
                    message  => 'I18N_OPENXPKI_SERVER_NOTIFICATION_FAILED_TO_INSTANTIATE_NOTIFIER',
                    params   => {
                        PKI_REALM => $pki_realm,
                        TYPE      => $notifier_type, 
                        NAME      => $notifier,
                        ERROR     => $EVAL_ERROR,
                    },
                    log      => {
                        logger   => CTX('log'),
                        priority => 'error',
                        facility => 'system',
                    },
                );
            }
            # attach notifier object to the notifier_of structure
            $notifier_of{$ident}->{$pki_realm}->[$ii]->{OBJECT}
                = $notifier_obj;
            $notifier_of{$ident}->{$pki_realm}->[$ii]->{NAME}
                = $notifier;
        }
    }
    ##! 64: 'notifier_of: ' . Dumper $notifier_of{$ident}

    return 1; 
}

sub notify {
    ##! 1: 'start'
    my $self      = shift;
    my $arg_ref   = shift;
    my $ident     = ident $self;
    
    if (ref $arg_ref ne 'HASH') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_NOTIFY_WRONG_ARGUMENT_TYPE',
            params => {
                'TYPE'     => ref $arg_ref,
                'ARGUMENT' => $arg_ref,
            },
        );
    }
    my $message   = $arg_ref->{MESSAGE};
    my $workflow  = $arg_ref->{WORKFLOW};
    my $pki_realm = CTX('session')->get_pki_realm();
    my $language  = CTX('session')->get_language();

    my $ser = OpenXPKI::Serialization::Simple->new();
    my $ticket = {};
    if (defined $workflow->context->param('ticket')) {
        # ticket IDs are present in the workflow context, pass
        # them on to the notifiers
        $ticket = $ser->deserialize($workflow->context->param('ticket'));
        ##! 64: 'ticket: ' . Dumper $ticket
    }

    my $results;

    # dispatch to all notifiers of the current PKI realm
    foreach my $notifier (@{$notifier_of{$ident}->{$pki_realm}}) {
        my $notifier_obj  = $notifier->{OBJECT};
        my $notifier_name = $notifier->{NAME};
        eval {
            ##! 16: 'dispatching to notifier of type ' . ref $notifier
            $results->{$notifier_name} = $notifier_obj->notify({
                MESSAGE  => $message,
                WORKFLOW => $workflow,
                LANGUAGE => $language,
                TICKET   => $ticket->{$notifier_name},
            });
        };
        if (my $exc = OpenXPKI::Exception->caught()) {
            OpenXPKI::Exception->throw(
                message  => 'I18N_OPENXPKI_SERVER_NOTIFICATION_DISPATCHER_DISPATCH_FAILED',
                children => [ $exc ],
                params   => {
                    PKI_REALM => $pki_realm,
                    TYPE      => ref $notifier, 
                },
                log      => {
                    logger   => CTX('log'),
                    priority => 'warn',
                    facility => 'system',
                },
            );
        }
        elsif ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message  => 'I18N_OPENXPKI_SERVER_NOTIFICATION_DISPATCHER_DISPATCH_FAILED',
                params   => {
                    PKI_REALM => $pki_realm,
                    TYPE      => ref $notifier, 
                    ERROR     => $EVAL_ERROR,
                },
                log      => {
                    logger   => CTX('log'),
                    priority => 'warn',
                    facility => 'system',
                },
            );
        }
    }
    ##! 1: 'end'
    return $results;
}

sub get_ticket_info {
    ##! 1: 'start'
    my $self      = shift;
    my $ident     = ident $self;
    my $arg_ref   = shift;
    my $notifier  = $arg_ref->{NOTIFIER};
    my $ticket    = $arg_ref->{TICKET};
    my $pki_realm = CTX('session')->get_pki_realm();

    if (! defined $notifier_of{$ident}->{$pki_realm} ) {
        return undef;
    }
    my $count = scalar (@{ $notifier_of{$ident}->{$pki_realm} });

    # find the right notifier
    for (my $i = 0; $i < $count; $i++) {
        my $not = $notifier_of{$ident}->{$pki_realm}->[$i];
        if ($not->{NAME} eq $notifier) {
            my $info;
            eval {
                # try to get a ticket URL from the notifier
                $info = $not->{OBJECT}->get_ticket_info($ticket);
            };
            return $info;
        }
    }
    return undef;
}

sub get_url_for_ticket {
    ##! 1: 'start'
    my $self      = shift;
    my $ident     = ident $self;
    my $arg_ref   = shift;
    my $notifier  = $arg_ref->{NOTIFIER};
    my $ticket    = $arg_ref->{TICKET};
    my $pki_realm = CTX('session')->get_pki_realm();

    if (! defined $notifier_of{$ident}->{$pki_realm} ) {
        return '';
    }
    my $count = scalar (@{ $notifier_of{$ident}->{$pki_realm} });

    # find the right notifier
    for (my $i = 0; $i < $count; $i++) {
        my $not = $notifier_of{$ident}->{$pki_realm}->[$i];
        if ($not->{NAME} eq $notifier) {
            my $url = '';
            eval {
                # try to get a ticket URL from the notifier
                $url = $not->{OBJECT}->get_url_for_ticket($ticket);
            };
            return $url;
        }
    }
    ##! 1: 'end'
    return '';
}

sub ticket_exists {
    ##! 1: 'start'
    my $self      = shift;
    my $ident     = ident $self;
    my $arg_ref   = shift;
    my $notifier  = $arg_ref->{NOTIFIER};
    my $ticket    = $arg_ref->{TICKET};
    my $pki_realm = CTX('session')->get_pki_realm();

    if (! defined $notifier_of{$ident}->{$pki_realm} ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_DISPATCHER_NO_NOTIFIERS_DEFINED_FOR_PKI_REALM',
        );
    }
    my $count = scalar (@{ $notifier_of{$ident}->{$pki_realm} });

    # find the right notifier
    for (my $i = 0; $i < $count; $i++) {
        my $not = $notifier_of{$ident}->{$pki_realm}->[$i];
        if ($not->{NAME} eq $notifier) {
            my $rc;
            eval {
                # try to get a ticket URL from the notifier
                $rc = $not->{OBJECT}->ticket_exists($ticket);
            };
            if ($rc) {
                # ticket exists
                return 1;
            }
        }
    }
    ##! 1: 'end'
    return 0;
}

sub __get_notifier_type :PRIVATE {
    ##! 1: 'start'
    my $self     = shift;
    my $notifier = shift;
    my $cfg_id   = shift;

    my $config   = CTX('xml_config');

    my $nr_of_all_notifiers = $config->get_xpath_count(
        XPATH     => [ 'common', 'notification_config', 'notifier' ],
        COUNTER   => [ 0       , 0                   ],
        CONFIG_ID => $cfg_id,
    );
    ##! 16: 'nr_of_all_notifiers: ' . $nr_of_all_notifiers

    my $index;
  NOTIFIER_INDEX:
    for (my $i = 0; $i < $nr_of_all_notifiers; $i++) {
        my $notifier_name = $config->get_xpath(
          XPATH   => [ 'common', 'notification_config', 'notifier', 'id' ],
          COUNTER => [ 0       , 0                    , $i        , 0    ],
          CONFIG_ID => $cfg_id,
        );
        if ($notifier_name eq $notifier) {
            $index = $i;
            last NOTIFIER_INDEX;
        }
    }
    if (! defined $index) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_DISPATCHER_COULD_NOT_FIND_CONFIG_ENTRY_FOR_NOTIFIER',
            params  => {
                NOTIFIER => $notifier,
            },
        );
    }

    my $notifier_type = $config->get_xpath(
        XPATH   => [ 'common', 'notification_config', 'notifier',
                     'notification_backend', 'type' ],
        COUNTER => [ '0'     , 0                    , $index    ,
                     0                     , 0      ],
        CONFIG_ID => $cfg_id,
    );
    ##! 16: 'notifier_type: ' . $notifier_type

    return $notifier_type;
}

1;

__END__

=head1 Name

OpenXPKI::Server::Notification::Dispatcher - A notification dispatcher

=head1 Description

This class implements the notification dispatcher. An object of this
class is instantiated during server initialzation and available from
the server context as CTX('notification'). Typically, workflow
activities call CTX('notification')->notify(), which then uses this
class to dispatch the notifications to all configured notifiers for
the given PKI realm.

=head1 Functions

=over

=item * START

Is the constructor. Goes through the configuration and initializes
all configured notifiers. They are saved in the attributes %notifier_of,
which is a hashref that contains an array of notifier objects for each
PKI realm.

=item * notify

Using the named parameters MESSAGE and WORKFLOW, it dispatches the
notification to all notifiers in the current PKI realm.

=item * __get_notifier_type

Gets the notifier type from the configuration for a given notifier
name. 

=item * get_url_for_ticket

Dispatches the get_url_for_ticket call to all configured notifiers
to retrieve the URL for a given ticket. Returns a hash reference
of notifiers and their respective URLs. Called by the corresponding
API method. Returns the empty string for notifiers that do not
have the get_url_for_ticket method implemented.

=back
