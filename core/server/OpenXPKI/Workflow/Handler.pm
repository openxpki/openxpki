# OpenXPKI::Workflow::Handler
#
# Written 2012 by Oliver Welter for the OpenXPKI project
# Copyright (C) 2012 by The OpenXPKI Project
#
#
=head1 OpenXPKI::Workflow::Handler

Handler class that manages the workflow factories for the different realms
and configuration states. The class is created on server init and stored
in the context as workflow_handler. It always creates one factory using the
workflow definitions from the current head version for each realm. You can
specify additional instances that should be created to the constructor.

=cut

package OpenXPKI::Workflow::Handler;

use strict;
use warnings;
use English;
use Moose;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Workflow::Factory;
use OpenXPKI::Workflow::Config;
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::XML::Cache;
use Data::Dumper;

has '_cache' => (
    is => 'rw',
    isa => 'HashRef',
    required => 0,
    default => sub { return {}; }
);

has '_workflow_config' => (
    is => 'ro',
    isa => 'HashRef',
    builder => '_init_workflow_config',
);

sub BUILD {
    my $self = shift;
    my $args = shift;

}

=head2 load_default_factories

Loads the most current workflow definiton for each realm.

=cut
sub load_default_factories {
    ##! 1: 'start'
    my $self = shift;
    my @realms = CTX('config')->get_keys('system.realms');
    foreach my $realm (@realms) {
        ##! 8: 'load realm $realm'
        $self->_cache->{$realm} = undef;
        CTX('session')->set_pki_realm( $realm );
        $self->get_factory();
    }
}

=head2 get_workflow { ID }

This is a shortcut method that expects only a workflow id and will take care
of finding the correct version and workflow type and returns an instance of
OpenXPKI::Workflow.

=cut
sub get_workflow {

    my $self = shift;
    my $args = shift;

    my $wf_id = $args->{ID};

    # Due to the mysql transaction model we MUST make a commit to refresh the view
    # on the database as we can have parallel process on the same workflow!
    CTX('dbi_workflow')->commit();

    # Fetch the workflow details from the workflow table
    ##! 16: 'determine factory for workflow ' . $arg_ref->{WORKFLOW_ID}
    my $wf = CTX('dbi_workflow')->first(
        TABLE   => 'WORKFLOW',
        KEY => $wf_id
    );
    if (! defined $wf) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_HANDLER_GET_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFO',
            params  => {
                WORKFLOW_ID => $wf_id,
            },
        );
    }

    # We can not load workflows from other realms as this will break config and security
    # The watchdog switches the session realm before instantiating a new factory
    if (CTX('session')->get_pki_realm() ne $wf->{PKI_REALM}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_HANDLER_GET_WORKFLOW_REALM_MISSMATCH',
            params  => {
                WORKFLOW_ID => $wf_id,
                WORKFLOW_REALM => $wf->{PKI_REALM},
                SESSION_REALM => CTX('session')->get_pki_realm()
            },
        );
    }

    my $wf_session_info = CTX('session')->parse_serialized_info($wf->{WORKFLOW_SESSION});
    if (!$wf_session_info || ref $wf_session_info ne 'HASH') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_HANDLER_GET_WORKFLOW_UNABLE_TO_PARSE_WORKFLOW_INFO',
            params  => {
                WORKFLOW_ID => $wf_id,
                WORKFLOW_SESSION => $wf->{WORKFLOW_SESSION}
            },
        );
    }

    # We have now obtained the configuration id that was active during
    # creation of the workflow instance. However, if for some reason
    # the matching configuration is not available we have two options:
    # 1. bail out with an error
    # 2. accept that there is an error and continue anyway with a different
    #    configuration
    # Option 1 is not ideal: if the corresponding configuration has for
    # some reason be deleted from the database the workflow cannot be
    # instantiated any longer. This is often not really a problem but
    # sometimes this will lead to severe problems, e. g. for long
    # running workflows. unfortunately, if a workflow cannot be instantiated
    # it can neither be displayed, nor executed.
    # In order to make things a bit more robust fall back to using a newer
    # configuration than the one missing. As we don't have a timestamp
    # for the configuration, a safe bet is to use the current configuration.
    # Caveat: the current workflow definition might not be compatible with
    # the particular workflow instance. There is a risk that the workflow
    # instance gets stuck in an unreachable state.
    # In comparison to not being able to even view the workflow this seems
    # to be an acceptable tradeoff.

    my $factory = $self->get_factory();

    ##! 64: 'factory: ' . Dumper $factory
    if (! defined $factory) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_HANDLER_GET_WORKFLOW_FACTORY_NOT_DEFINED',
        );
    }

    my $workflow = $factory->fetch_workflow( $wf->{'WORKFLOW_TYPE'}, $wf_id );

    return $workflow;

}

=head2 get_factory( VERSION, FALLBACK )

Return a workflow factory using the versioned config.

=item VERSION The config version hash to use

=item FALLBACK 0|1 weather to fallback to current if version is not found

=cut
sub get_factory {

    ##! 1: 'start'

    my $self = shift;
    my $args = shift;

    ##! 16: Dumper $args

    # Testing and special purpose shortcut - get an unregistered factory from an existing xml config
    if ($args->{XML_CONFIG}) {
        OpenXPKI::Exception->throw('message' => 'Workflow XML Format is no longer supported');
    }

    # TODO - MIGRATION - remove xml stuff after migration is complete

    my $pki_realm = CTX('session')->get_pki_realm();
    # Check if we already have that factory in the cache
    if (defined $self->_cache->{ $pki_realm } ) {
        return $self->_cache->{ $pki_realm };
    }

    # Fetch the serialized Workflow definition from the config layer
    my $conn = CTX('config');

    my $workflow_serialized_config = $conn->get('workflow.xml');

    # Test if there is a yaml config to load
    my $yaml_config;
    if ($conn->exists('workflow.def')) {
        $yaml_config = OpenXPKI::Workflow::Config->new()->workflow_config();
    }

    my $workflow_factory;
    if ($workflow_serialized_config) {
        my $xml_config = OpenXPKI::XML::Cache->new( SERIALIZED_CACHE => $workflow_serialized_config );
        $workflow_factory = OpenXPKI::Workflow::Handler::__get_instance ({
            XML_CONFIG => $xml_config,
            WF_CONFIG_MAP => $self->_workflow_config(),
            FAKE_MISSING_CLASSES => 1
        });
    }

    if ($yaml_config) {
        $workflow_factory = OpenXPKI::Workflow::Factory->new() unless ($workflow_factory);
        $workflow_factory->add_config( %{$yaml_config} );
    }

    ##! 32: Dumper $workflow_factory


    $self->_cache->{ $pki_realm } = $workflow_factory;

    return $workflow_factory;

}


# Legacy XML Format, extracted from previously removed code


sub _init_workflow_config {

    return {
     # how we name it in our XML configuration file
         workflows => {
             # how the parameter is called for Workflow::Factory
             factory_param => 'workflow',
             # if this key exists, we assume that no <configfile>
             # is specified but the XML config is included directly
             # and iterate over it to obtain the configuration which
             # we pass to Workflow::Factory->add_config()
             config_key    => 'workflow',
             # the ForceArray XML::Simple option used in Workflow
             # that we have to recreate using __flatten_content()
             # the content is taken from Workflow::Config::XML
             force_array   => [ 'extra_data', 'state', 'action',  'resulting_state', 'condition', 'observer' ],
         },
         activities => {
             factory_param   => 'action',
             config_key      => 'actions',
             # if this key is present, we iterate over two levels:
             # first over all config_keys and then over all
             # config_iterators and add the corresponding structure
             # to the Workflow factory using add_config()
             config_iterator => 'action',
             force_array     => [ 'action', 'field', 'source_list', 'param', 'validator', 'arg' ],
         },
         validators => {
             factory_param   => 'validator',
             config_key      => 'validators',
             config_iterator => 'validator',
             force_array     => [ 'validator', 'param' ],
         },
         conditions => {
             factory_param   => 'condition',
             config_key      => 'conditions',
             config_iterator => 'condition',
             force_array     => [ 'condition', 'param' ],
         },
    };

}


sub __get_instance {

    ##! 1: 'start'

    my $arg_ref = shift;

    my $xml_config = $arg_ref->{XML_CONFIG};
    my $workflow_config  = $arg_ref->{WF_CONFIG_MAP};
    my $fake_missing_classes = $arg_ref->{FAKE_MISSING_CLASSES};
    my $workflow_factory = OpenXPKI::Workflow::Factory->new();

    ##! 129: "xml_config: " .  Dumper $xml_config

    foreach my $type (qw( conditions validators activities workflows )) {

        ##! 64: "Setup $type"
        my @base_path = (
            'workflow_config',
            $type,
            $workflow_config->{$type}->{config_key},
        );
        my @base_ctr  = ( 0, 0 );

        my $toplevel_count = 0;
        eval {
            $toplevel_count = $xml_config->get_xpath_count(
                XPATH     => [ @base_path ],
                COUNTER   => [ 0, 0],
            );
        };
        ##! 64: "Toplevel Count is $toplevel_count on " . join "-", @base_path
        for (my $ii = 0; $ii < $toplevel_count; $ii++) {

            if (exists $workflow_config->{$type}->{'config_iterator'}) {
                # we need to iterate over a second level
                my $iterator
                    = $workflow_config->{$type}->{'config_iterator'};

                my $secondlevel_count = 0;
                eval {
                    $secondlevel_count = $xml_config->get_xpath_count(
                        XPATH     => [ @base_path, $iterator ],
                        COUNTER   => [ @base_ctr, $ii ],
                    );
                };
                ##! 16: 'secondlevel_count: ' . $secondlevel_count
                for (my $iii = 0; $iii < $secondlevel_count; $iii++) {
                    my $entry = $xml_config->get_xpath_hashref(
                        XPATH     => [ @base_path, $iterator ],
                        COUNTER   => [ @base_ctr , $ii, $iii      ],
                    );
                    ##! 32: 'entry ' . $iii . ': ' . Dumper $entry
                    # '__flatten_content()' turns our XMLin
                    # structure into the one compatible to Workflow

                    # When using an older config, some classes might be deleted
                    # so we fake the class name to be a stub class if its missing
                    # so the workflow factory can load it
                    # this will obviously not make the workflow run!
                    # Due to the structure of the XML all class definitions go thru this
                    # branch and never the one below, so its ok to have this only here
                    if ($fake_missing_classes && $entry->{class}) {
                        eval "require $entry->{class}";
                        if ($EVAL_ERROR) {
                            CTX('log')->log(
                                MESSAGE => 'Fake missing workflow class ' . $entry->{class},
                                PRIORITY => 'warn',
                                FACILITY => 'application'
                            );
                            $entry->{class} = 'OpenXPKI::Server::Workflow::Stub';
                        }
                    }

                    $workflow_factory->add_config(
                        $workflow_config->{$type}->{factory_param} =>
                            OpenXPKI::Workflow::Handler::__flatten_content(
                                $entry,
                                $workflow_config->{$type}->{'force_array'}
                            ),
                    );
                    ##! 256: 'workflow_factory: ' . Dumper $workflow_factory
                }
            } # else iterator
            else {
                my $entry = $xml_config->get_xpath_hashref(
                    XPATH     => [ @base_path ],
                    COUNTER   => [ @base_ctr, $ii ],
                );
                ##! 32: "entry: " . Dumper $entry
                # Flatten some attributes because
                # Workflow.pm expects these to be scalars and not
                # a one-element arrayref with a content hashref ...
                $entry = OpenXPKI::Workflow::Handler::__flatten_content(
                    $entry,
                    $workflow_config->{$type}->{force_array}
                );
                ##! 256: 'entry after flattening: ' . Dumper $entry
                ##! 512: 'workflow_factory: ' . Dumper $workflow_factory
                $workflow_factory->add_config(
                    $workflow_config->{$type}->{factory_param} => $entry,
                );
                ##! 256: 'workflow_factory: ' . Dumper $workflow_factory
            }
        }
    }
    ##! 64: 'config added completely'

    my $workflow_table = 'WORKFLOW';
    my $workflow_history_table = 'WORKFLOW_HISTORY';
    # persister configuration should not be user-configurable and is
    # static and identical throughout OpenXPKI
    $workflow_factory->add_config(
        persister => {
            name           => 'OpenXPKI',
            class          => 'OpenXPKI::Server::Workflow::Persister::DBI',
            workflow_table => $workflow_table,
            history_table  => $workflow_history_table,
        },
    );

    ##! 1: 'end'
    return $workflow_factory;
}

sub __flatten_content {

    my $entry       = shift;
    my $force_array = shift;
    # as this method calls itself a large number of times recursively,
    # the debug levels are /a bit/ higher than usual ...
    ##! 256: 'entry: ' . Dumper $entry
    ##! 256: 'force_array: ' . Dumper $force_array;

    foreach my $key (keys %{$entry}) {
        if (ref $entry->{$key} eq 'ARRAY' &&
            scalar @{ $entry->{$key} } == 1 &&
            ref $entry->{$key}->[0] eq 'HASH' &&
            exists $entry->{$key}->[0]->{'content'} &&
            scalar keys %{ $entry->{$key}->[0] } == 1) {
            ##! 256: 'key: ' . $key . ', flattening (deleting array)'
            if (grep {$_ eq $key} @{ $force_array}) {
                ##! 256: 'force array'
                $entry->{$key} = [ $entry->{$key}->[0]->{'content'} ];
            }
            else {
                ##! 256: 'no force array - replacing array by scalar'
                $entry->{$key} = $entry->{$key}->[0]->{'content'};
            }
        }
        elsif (ref $entry->{$key} eq 'ARRAY') {
            ##! 256: 'entry is array but more than one element'
            for (my $i = 0; $i < scalar @{ $entry->{$key} }; $i++) {
                ##! 256: 'i: ' . $i
                if (ref $entry->{$key}->[$i] eq 'HASH') {
                    if (exists $entry->{$key}->[$i]->{'content'}) {
                        ##! 256: 'entry #' . $i . ' has content key, flattening'
                        $entry->{$key}->[$i]
                            = $entry->{$key}->[$i]->{'content'};
                    }
                    else {
                        ##! 256: 'entry #' . $i . ' does not have content key'
                        ##! 512: ref $entry->{$key}->[$i]
                        if (ref $entry->{$key}->[$i] eq 'HASH') {
                            # no need to flatten scalars any more
                            ##! 256: 'recursively flattening more ...'
                            $entry->{$key}->[$i] = OpenXPKI::Workflow::Handler::__flatten_content(
                                $entry->{$key}->[$i],
                                $force_array
                            );
                        }
                    }
                }
            }
        }
    }
    return $entry;
}





1;

__END__
