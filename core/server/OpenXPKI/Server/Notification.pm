## OpenXPKI::Server::Notification
## abstract notifier baseclass
##
## Written 2007 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project

package OpenXPKI::Server::Notification;

use strict;
use warnings;
use English;

use Class::Std;

use Data::Dumper;

use OpenXPKI::Debug;
use OpenXPKI::Exception;

use OpenXPKI::Serialization::Simple;
use Template;

my %pki_realm_of     :ATTR( :init_arg<PKI_REALM> ); 
my %name_of          :ATTR( :init_arg<NAME>      ); # name of the notifier
my %config_of        :ATTR( :init_arg<CONFIG>    ); # the XML config
my %config_id_of     :ATTR( :init_arg<CONFIG_ID> ); # the config identifier
        
sub START {
    ##! 2: 'start'
    my $self    = shift;
    my $ident   = shift;

   if (ref $self eq 'OpenXPKI::Server::Notification') {
        # somebody tried to instantiate us, but we are abstract.
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_IS_ABSTRACT_CLASS',
        );
    }
    
    ##! 2: 'end'
    return 1; 
}

sub notify {
    ##! 1: 'start'
    my $self      = shift;
    my $arg_ref   = shift;
    my $ident     = ident $self;

    my $message   = $arg_ref->{MESSAGE};
    my $workflow  = $arg_ref->{WORKFLOW};
    my $language  = $arg_ref->{LANGUAGE};
    my $ticket    = $arg_ref->{TICKET};

    ##! 16: 'sending notification for ' . $message . ' in ' . $language
    ##! 16: 'ticket: ' . $ticket

    $self->__pre_notification();

    my $notifier_index     = $self->__get_notifier_index();
    my $notification_index = $self->__get_notification_index($message); 

    my @xpath   = ( 'common', 'notification_config', 'notifier'     ,
                    'notifications', 'notification' );
    my @counter = ( 0       , 0                    , $notifier_index,
                    0              , $notification_index );


    my $action_count = $config_of{$ident}->get_xpath_count(
        XPATH     => [ @xpath  , 'action' ],
        COUNTER   => [ @counter ],       
        CONFIG_ID => $config_id_of{$ident},
    );
    ##! 16: 'number of actions to do: ' . $action_count

   
    my $new_ticket_id;
    for (my $i = 0; $i < $action_count; $i++) {
        my $action_type = $config_of{$ident}->get_xpath(
            XPATH    => [ @xpath  , 'action', 'type' ],
            COUNTER  => [ @counter, $i      , 0      ],
            CONFIG_ID => $config_id_of{$ident},
        );
        ##! 16: 'action_type: ' . $action_type
        my $method_name = '__do_' . $action_type;
        my $result = $self->$method_name({
            XPATH    => [ @xpath  , 'action' ],
            COUNTER  => [ @counter, $i       ],
            WORKFLOW => $workflow,
            TICKET   => defined $new_ticket_id ? $new_ticket_id : $ticket,
        });
        if ($action_type eq 'open' && defined $result) {
            # the result is the freshly created ticket ID,
            # return it to the user so that it can be set in the
            # workflow 
            $new_ticket_id = $result; 
        }
    }

    $self->__post_notification();

    ##! 16: 'new ticket id: ' . $new_ticket_id
    ##! 1: 'end'
    return $new_ticket_id;
}

############# ACTION METHODS CALLED FROM NOTIFY #######################

sub __do_open :PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;

    my $requestors = $self->__get_action_config_value({
        %{ $arg_ref },
        KEY      => 'requestor',
    });
    if (ref $requestors ne 'ARRAY') {
        # only one requestor has been specified, make it a single
        # element array reference
        $requestors = [ $requestors ];
    }
    my $queue = $self->__get_action_config_value({
        %{ $arg_ref },
        KEY      => 'queue',
    });
    my $subject = $self->__get_action_config_value({
        %{ $arg_ref },
        KEY      => 'subject',
    });
    # call open in the notifier implementation
    my $ticket_id = $self->open({
        REQUESTORS => $requestors,
        QUEUE      => $queue,
        SUBJECT    => $subject,
    });

    ##! 16: 'ticket_id: ' . $ticket_id
    ##! 1: 'end'
    return $ticket_id;
}

sub __do_correspond :PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;

    my $content = $self->__get_action_config_template($arg_ref);
    ##! 64: 'content: ' . $content

    if (!defined $content || $content eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_EMPTY_OR_UNDEFINED_CONTENT',
        );
    }
    # call correspond in the notifier implementation
    $self->correspond({
        TICKET  => $arg_ref->{TICKET},
        CONTENT => $content,
    });

    ##! 1: 'end'
    return;
}

sub __do_comment :PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;

    my $content = $self->__get_action_config_template($arg_ref);
    ##! 64: 'content: ' . $content
    if (!defined $content || $content eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_EMPTY_OR_UNDEFINED_CONTENT',
        );
    }

    # call comment in the notifier implementation
    $self->comment({
        TICKET  => $arg_ref->{TICKET},
        CONTENT => $content,
    });

    ##! 1: 'end'
    return;
}

sub __do_set_value :PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;
    my $ticket  = $arg_ref->{TICKET};

    my $field = $self->__get_action_config_value({
        %{ $arg_ref },
        KEY      => 'field',
    });
    my $value = $self->__get_action_config_value({
        %{ $arg_ref },
        KEY      => 'value',
    });
    # call set_value in the notifier implementation
    ##! 16: 'setting ' . $field . '=' . $value . ' for ticket ' . $ticket
    $self->set_value({
        FIELD  => $field,
        VALUE  => $value,
        TICKET => $ticket,
    });

    ##! 1: 'end'
    return;
}

sub __do_create_link :PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;
    my $ticket  = $arg_ref->{TICKET};

    my $link_type = $self->__get_action_config_value({
        %{ $arg_ref },
        KEY      => 'link_type',
    });
    my $link = $self->__get_action_config_value({
        %{ $arg_ref },
        KEY      => 'link',
    });
    # call link_tickets in the notifier implementation
    ##! 16: 'creating link of type ' . $link_type . 'for ticket ' . $ticket . 'with content: ' . $link
    $self->link_tickets({
        TYPE   => $link_type,
        LINK   => $link,
        TICKET => $ticket,
    });

    ##! 1: 'end'
    return;
}

sub __do_close :PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;

    # call close in the notifier implementation
    $self->close({
        TICKET  => $arg_ref->{TICKET},
    });

    ##! 1: 'end'
    return;
}

##################### HELPER METHODS #########################

sub __get_backend_config_value {
    ##! 1: 'start'
    my $self          = shift;
    my $ident         = ident $self;
    my $config_key    = shift;

    my $index = $self->__get_notifier_index();
    my $config_value = $config_of{$ident}->get_xpath(
        XPATH     => [ 'common', 'notification_config', 'notifier',
                       'notification_backend', "$config_key" ],
        COUNTER   => [ 0       , 0                    , $index    ,
                       0                     , 0             ],
        CONFIG_ID => $config_id_of{$ident},
    );
    ##! 16: 'config_value for ' . $config_key . ': ' . $config_value 

    ##! 1: 'end'
    return $config_value;
}

sub __get_notifier_index :PRIVATE {
    ##! 1: 'start'
    my $self     = shift;
    my $ident    = ident $self;

    my $notifier = $name_of{$ident};
    my $config   = $config_of{$ident};

    my $nr_of_all_notifiers = $config->get_xpath_count(
        XPATH     => [ 'common', 'notification_config', 'notifier' ],
        COUNTER   => [ 0       , 0                   ],
        CONFIG_ID => $config_id_of{$ident},
    );
    ##! 16: 'nr_of_all_notifiers: ' . $nr_of_all_notifiers

    my $index;
  NOTIFIER_INDEX:
    for (my $i = 0; $i < $nr_of_all_notifiers; $i++) {
        my $notifier_name = $config->get_xpath(
          XPATH   => [ 'common', 'notification_config', 'notifier', 'id' ],
          COUNTER => [ 0       , 0                    , $i        , 0    ],
          CONFIG_ID => $config_id_of{$ident},
        );
        if ($notifier_name eq $notifier) {
            $index = $i;
            last NOTIFIER_INDEX;
        }
    }
    if (! defined $index) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_COULD_NOT_FIND_CONFIG_ENTRY_FOR_NOTIFIER',
            params  => {
                NOTIFIER => $notifier,
            },
        );
    }

    ##! 1: 'end'
    return $index;
}

sub __get_notification_index :PRIVATE {
    ##! 1: 'start'
    my $self         = shift;
    my $ident        = ident $self;
    my $notification = shift;

    my $n_index = $self->__get_notifier_index();
    my $config  = $config_of{$ident};

    my @xpath   = ( 'common', 'notification_config', 'notifier' ,
                    'notifications', 'notification' );
    my @counter = ( 0       , 0                    , $n_index   ,
                    0               );

    my $nr_of_notifications = $config->get_xpath_count(
        XPATH     => [ @xpath   ],
        COUNTER   => [ @counter ],
        CONFIG_ID => $config_id_of{$ident},
    );
    ##! 16: 'nr_of_notifications: ' . $nr_of_notifications

    my $index;
  NOTIFICATION_INDEX:
    for (my $i = 0; $i < $nr_of_notifications; $i++) {
        my $notification_name = $config->get_xpath(
          XPATH     => [ @xpath,      'id' ],
          COUNTER   => [ @counter, $i, 0   ],
          CONFIG_ID => $config_id_of{$ident},
        );
        if ($notification_name eq $notification) {
            $index = $i;
            last NOTIFICATION_INDEX;
        }
    }
    if (! defined $index) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_COULD_NOT_FIND_CONFIG_ENTRY_FOR_NOTIFICATION',
            params  => {
                NOTIFICATION => $notification,
            },
        );
    }

    ##! 1: 'end'
    return $index;
}

sub __get_action_config_template :PRIVATE {
    ##! 1: 'start'
    my $self     = shift;
    my $ident    = ident $self;
    my $arg_ref  = shift;
    my @xpath    = @{ $arg_ref->{XPATH} };
    my @counter  = @{ $arg_ref->{COUNTER} };
    my $language = $arg_ref->{LANGUAGE};
    my $template_vars
        = $self->__workflow_to_template_vars($arg_ref->{WORKFLOW});

    ##! 64: 'arg_ref: ' . Dumper $arg_ref
    ##! 64: 'template_vars: ' . Dumper $template_vars

    my $count;
    eval {
        # get the number of entries for this key
        $count = $config_of{$ident}->get_xpath_count(
            XPATH     => [ @xpath  , 'template' ],
            COUNTER   => [ @counter ],
            CONFIG_ID => $config_id_of{$ident},
        );
    };
    if (! $count) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_NO_TEMPLATE_DEFINED',
        );
    }
    my $template_index;
  FIND_LANGUAGE_TEMPLATE:
    for (my $i = 0; $i < $count; $i++) {
        my $lang = $config_of{$ident}->get_xpath(
            XPATH     => [ @xpath  , 'template', 'lang' ],
            COUNTER   => [ @counter, $i        , 0      ],
            CONFIG_ID => $config_id_of{$ident},
        );
        if (defined $language && ($lang eq $language)) {
            $template_index = $i;
            last FIND_LANGUAGE_TEMPLATE;
        }
    }
    if (! defined $template_index) {
        # fall back to the first template if we did not find the
        # correct language
        ##! 64: 'no template found for language: ' . $language
        $template_index = 0;
    }
    my $filename = $config_of{$ident}->get_xpath(
        XPATH     => [ @xpath  , 'template'     , 'file' ],
        COUNTER   => [ @counter, $template_index, 0      ],
        CONFIG_ID => $config_id_of{$ident},
    );
    if (! -e $filename) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_TEMPLATE_FILE_DOES_NOT_EXIST',
            params  => {
                FILENAME => $filename,
            },
        );
    }
    if (! -r $filename) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_TEMPLATE_FILE_IS_NOT_READABLE',
            params  => {
                FILENAME => $filename,
            },
        );
    }

    my $content = do { # slurp
        local $INPUT_RECORD_SEPARATOR;
        open my $HANDLE, '<', $filename;
        <$HANDLE>;
    };
    $content = $self->__apply_template({
        TEMPLATE  => $content,
        VARIABLES => $template_vars,
    }); 

    ##! 64: 'content: ' . $content
    ##! 1: 'end'
    return $content;
}

sub __get_action_config_value :PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;
    my @xpath   = @{ $arg_ref->{XPATH} };
    my @counter = @{ $arg_ref->{COUNTER} };
    my $template_vars
        = $self->__workflow_to_template_vars($arg_ref->{WORKFLOW});

    ##! 64: 'arg_ref: ' . Dumper $arg_ref
    ##! 64: 'template_vars: ' . Dumper $template_vars

    my $count;
    my $value;
    eval {
        # get the number of entries for this key
        $count = $config_of{$ident}->get_xpath_count(
            XPATH     => [ @xpath  , $arg_ref->{KEY} ],
            COUNTER   => [ @counter ],
            CONFIG_ID => $config_id_of{$ident},
        );
    };
    if (! $count) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_NO_CONFIG_VALUE_FOR_ACTION',
            params  => {
                'KEY' => $arg_ref->{KEY},
            }
        );
    }
    elsif ($count == 1) { # scalar value
        $value = $config_of{$ident}->get_xpath(
            XPATH     => [ @xpath  , $arg_ref->{KEY} ],
            COUNTER   => [ @counter, 0               ],
            CONFIG_ID => $config_id_of{$ident},
        );
        $value = $self->__apply_template({
            TEMPLATE  => $value,
            VARIABLES => $template_vars
        }); 
    }
    else { # more than one, prepare an array reference
        for (my $i = 0; $i < $count; $i++) {
            $value->[$i] = $config_of{$ident}->get_xpath(
                XPATH     => [ @xpath  , $arg_ref->{KEY} ],
                COUNTER   => [ @counter, $i              ],
                CONFIG_ID => $config_id_of{$ident},
            );
            $value->[$i] = $self->__apply_template({
                TEMPLATE  => $value->[$i],
                VARIABLES => $template_vars
            }); 
        }
    }

    ##! 32: 'value for key ' . $arg_ref->{KEY} . ': ' . Dumper $value
    ##! 1: 'end'
    return $value;
}

sub __workflow_to_template_vars :PRIVATE {
    ##! 1: 'start'
    my $self     = shift;
    my $ident    = ident $self;
    my $workflow = shift;
    my $context  = $workflow->context()->{PARAMS};
    my $context_copy;

    foreach my $key (keys %{ $context }) {
        $context_copy->{$key} = $context->{$key};
    }
    # add some meta-information about the workflow that is not
    # present in the context
    $context_copy->{'META_PKI_REALM'} = $pki_realm_of{$ident};
    $context_copy->{'META_WF_ID'}     = $workflow->id();
    $context_copy->{'META_WF_TYPE'}   = $workflow->type();
    $context_copy->{'META_WF_STATE'}  = $workflow->state();

    my $serializer      = OpenXPKI::Serialization::Simple->new();
    my $dash_serializer = OpenXPKI::Serialization::Simple->new({
        SEPARATOR => '-',
    });
    foreach my $key (keys %{ $context_copy }) {
        # deserialize if possible
        if ($context_copy->{$key} =~ m{ \A HASH | \A ARRAY }xms) {
            my $deserialized;
            eval {
                $deserialized = $serializer->deserialize($context_copy->{$key});
            };
            if ($EVAL_ERROR || ! defined $deserialized) {
                # some data, such as the key data for a server-side generated
                # key, is serialized using '-' as a separator, deserialize
                # accordingly
                $deserialized = $dash_serializer->deserialize(
                    $context_copy->{$key},
                );
            }
            $context_copy->{$key} = $deserialized;
        }
    }

    ##! 1: 'end'
    return $context_copy;
}

sub __apply_template :PRIVATE {
    ##! 1: 'start'
    my $self     = shift;
    my $arg_ref  = shift;
    my $template = $arg_ref->{TEMPLATE};
    my $vars     = $arg_ref->{VARIABLES};
    my $result = '';

    ##! 16: 'template: ' . $template
    my $tt = Template->new();
    $tt->process(\$template, $vars, \$result) or OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_APPLY_TEMPLATE_PROCESSING_FAILED',
        params  => {
            TEMPLATE_ERROR => $tt->error(),
        },
    );
    ##! 16: 'result: ' . $result

    ##! 1: 'end'
    return $result;
}

sub __pre_notification :PRIVATE {
    # TO BE IMPLEMENTED IN CHILDREN CLASSES
    return 1;
}

sub __post_notification :PRIVATE {
    # TO BE IMPLEMENTED IN CHILDREN CLASSES
    return 1;
}

1;

__END__

=head1 Name

OpenXPKI::Server::Notification - abstract base notifier class

=head1 Description

This class is the abstract base class for all notifier classes.

=head1 Functions

=over




=item * START

Is the constructor. Throws an exception, as this class is abstract
and not meant to be instantiated.

=item * notify

Takes the named parameters MESSAGE and WORKFLOW and does the
actual notification.

Calls __pre_notification() first, to allow the actual implementation
to do the setup first, such as logging into a ticket system or so.

Then, it looks up the message in the XML configuration, goes through all
the actions and calls the corresponding methods ('__do_<action>').
These methods are supposed to be implemented by the particular
notifier (a child class) itself.

At the end, it calls __post_notification(), so that the implementations
can do some teardown work.

=item * __do_open

This private method is called by notify() when the action of opening
a ticket is requested. Takes the requestor, queue and subject from
the action configuration and passes them on to the open method of
the child (after having done the template substition). Returns the
ticket ID of the freshly created ticket.

=item * __do_correspond

This private method is called by notify() when a correspondence is
requested. Takes the template from the configuration, passes it through
Template Toolkit and on to the correspond() method implemented in
the child.

=item * __do_comment

This private method is called by notify() when a comment on a ticket is
requested. Takes the template from the configuration, passes it through
Template Toolkit and on to the comment() method implemented in
the child.

=item * __do_set_value

This private method is called by notify() when someone wants to change
a ticket value. Takes the parameters field and value from the config,
passes them through Template Toolkit and on to the set_value() method
implemented in the child.

=item * __do_create_link

This private method is called by notify() when someone wants to link
a ticket to another one (is probably pretty RT specific). Takes the
parameters link_type and link from the config, passes them through
Template Toolkit and on to the link_tickets() method implemented
in the child.

=item * __do_close

This private method is called by notify() when someone wants to close
a ticket. Calls the close() method implemented in the child.

=item * __get_backend_config_value

Get configuration values for the notification backend. Takes
a single parameter that specifies the XML tag used for the
configuration. This is used by the children to determine their
(implementation-dependent) configuration values.

=item * __get_notifier_index

This private method gets the index for get_xpath() for the given notifier.

=item * __get_notification_index

Gets the index number for get_xpath() for a given notification message.

=item * __get_action_config_value

Gets the value of a config item in an <action> definition. The returned
value has already been passed through Template Toolkit. If more than
one entry is defined, this returns an array reference containing
the values

=item * __get_action_config_template

Similarly, this private method gets the result of applying the
template defined in the template file configured for a certain
action (most notably for correspond and comment). The file
is chosen by looking at the current language. If the selected
language is not availabe, it falls back to the first template
specified.

=item * __workflow_to_template_vars

This private method translates the workflow context into a hash
that can then be used by Template Toolkit as variables in the
definition of notifications and configuration. In addition, it
adds META_PKI_REALM, META_WF_ID, META_WF_TYPE, META_WF_STATE
as variables that can be expanded, too, but were not available
in the original context.

=item * __apply_template

This private method is a wrapper around Template Toolkit. It applies
a given template to a variable and returns the result.

=item * __pre_notification

Abstract, to be implemented by the children classes. Called prior
to doing the notification (i.e. calling the actions)

=item * __post_notification

Abstract, to be implemented by the children classes. Called after
doing the notification (i.e. calling the actions)

=back
