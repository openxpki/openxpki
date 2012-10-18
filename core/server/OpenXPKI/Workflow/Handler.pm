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
        $self->_cache->{$realm} = {};
        CTX('session')->set_pki_realm( $realm );
        $self->get_factory();        
    }
}

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
      
=head2 get_factory({ PKI_REALM | VERSION }) or get_factory( { XML_CONFIG })

Retrieve the OpenXPKI::Workflow::Factory object for the given realm/version.
Both parameters are optional and default to the settings from the current 
Session.

If you pass an instance of OpenXPKI::XML::Config, you will receive a workflow
factory set up from this config. This factory is not registered in the internal
cache. 

=cut

sub get_factory {
    
    ##! 1: 'start'
    
    my $self = shift;
    my $args = shift;

    ##! 16: Dumper $args
        
    # Testing and special purpose shortcut - get an unregistered factory from an existing xml config        
    if ($args->{XML_CONFIG}) {
        return OpenXPKI::Workflow::Handler::__get_instance ({ XML_CONFIG => $args->{XML_CONFIG}, WF_CONFIG_MAP => $self->_workflow_config() });
    }
        
    $args->{PKI_REALM} = CTX('session')->get_pki_realm() unless($args->{PKI_REALM});
    $args->{VERSION} = CTX('session')->get_config_version() unless($args->{VERSION});
    
    ##! 16: "Probing realm $args->{PKI_REALM} version $args->{VERSION}"
    
    # Check if we already have that factory in the cache
    if ($self->_cache->{ $args->{PKI_REALM} }->{ $args->{VERSION} }) {        
        return $self->_cache->{ $args->{PKI_REALM} }->{ $args->{VERSION} };       
    }
    
    # Not found - if necessary make the session show the expected version/realm        
    my ($oldversion, $oldrealm);
    # Manipulate the VERSION 
    if ($args->{PKI_REALM} ne CTX('session')->get_pki_realm()) {
        $oldrealm = CTX('session')->get_pki_realm();
        CTX('session')->set_pki_realm( $args->{PKI_REALM} );
    }
      
    if ($args->{VERSION} ne CTX('session')->get_config_version()) {
        $oldversion = CTX('session')->get_config_version();
        CTX('session')->set_config_version( $args->{VERSION} );
    }
    
    # Fetch the serialized Workflow definition from the config layer 
    my $workflow_serialized_config = CTX('config')->get('workflow');
    
    # There might be cases where we request unknown config version
    if (!$workflow_serialized_config) {
         OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_HANDLER_GET_FACTORY_UNKNOWN_VERSION_REQUESTED',
            params => {
                PKI_REALM => $args->{PKI_REALM},
                VERSION => $args->{VERSION}
            }
        );
    }
    
    my $xml_config = OpenXPKI::XML::Cache->new( SERIALIZED_CACHE => $workflow_serialized_config );
    
    my $factory = OpenXPKI::Workflow::Handler::__get_instance ({ XML_CONFIG => $xml_config, WF_CONFIG_MAP => $self->_workflow_config() });    
    $self->_cache->{ $args->{PKI_REALM} }->{ $args->{VERSION} } = $factory;
    
    CTX('session')->set_pki_realm( $oldrealm ) if ($oldrealm);
    CTX('session')->set_config_version( $oldversion ) if ($oldversion);

    return $factory;    
}


sub __get_instance {
    
    ##! 1: 'start'
    
    my $arg_ref = shift;
    
    my $xml_config = $arg_ref->{XML_CONFIG};
    my $workflow_config  = $arg_ref->{WF_CONFIG_MAP};    
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