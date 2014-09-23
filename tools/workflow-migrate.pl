#!/usr/bin/perl

# Helper script to create a basic yaml representation from exisiting
# xml workflow definition.
use strict;
use OpenXPKI::Workflow::Factory;
use OpenXPKI::XML::Cache;
use Data::Dumper;
use Digest::SHA qw(sha1_hex);
use Log::Log4perl qw(:easy);

my $config = shift;
my $wf_type = shift;
my $target = shift;

if (!$config) {
    print "Given path to workflow.xml as first argument\n";
    exit 1;
}

Log::Log4perl->easy_init($ERROR);

my $xml_config = OpenXPKI::XML::Cache->new( CONFIG => $config );
my @yaml;

# stolen from  Data::YAML::Writer
sub _write {
    my $prefix = shift;
    my $obj    = shift;
    my $indent = shift || 1;

    if ( my $ref = ref $obj ) {
        if ( 'HASH' eq $ref ) {
            if (!%{$obj}) { return; }
            push @yaml, $prefix;

            my $pad = '    ' x $indent;
            # Force order on known attributes
            foreach my $key (qw(autorun prefix class uihandle label name description action placeholder tooltip required type input param arg)) {
                if ($obj->{$key}) {
                    _write( $pad . $key . ': ', $obj->{$key}, $indent + 1 );
                    delete $obj->{$key};
                }
            }
            for my $key ( sort keys %$obj ) {
                _write( $pad . $key . ': ', $obj->{$key}, $indent + 1 );
            }
        }
        elsif ( 'ARRAY' eq $ref ) {
            if (!@{$obj}) { return; }
            push @yaml, $prefix;
            my $pad = '    ' x ($indent - 1);
            for my $value (@$obj) {
                _write( $pad . '  - ', $value, $indent + 1 );
            }
        }
        else {
        }
    }
    else {
        push @yaml, $prefix . $obj;
    }

    if ($indent == 2) {
        push @yaml, "";
    }
}

sub __flatten_content {

    my $entry       = shift;
    my $force_array = shift;

    # as this method calls itself a large number of times recursively,
    # the debug levels are /a bit/ higher than usual ...
    ##! 256: 'entry: ' . Dumper $entry
    ##! 256: 'force_array: ' . Dumper $force_array;

    foreach my $key ( keys %{$entry} ) {
        if (   ref $entry->{$key} eq 'ARRAY'
            && scalar @{ $entry->{$key} } == 1
            && ref $entry->{$key}->[0] eq 'HASH'
            && exists $entry->{$key}->[0]->{'content'}
            && scalar keys %{ $entry->{$key}->[0] } == 1 )
        {
            ##! 256: 'key: ' . $key . ', flattening (deleting array)'
            if ( grep { $_ eq $key } @{$force_array} ) {
                ##! 256: 'force array'
                $entry->{$key} = [ $entry->{$key}->[0]->{'content'} ];
            }
            else {
                ##! 256: 'no force array - replacing array by scalar'
                $entry->{$key} = $entry->{$key}->[0]->{'content'};
            }
        }
        elsif ( ref $entry->{$key} eq 'ARRAY' ) {
            ##! 256: 'entry is array but more than one element'
            for ( my $i = 0 ; $i < scalar @{ $entry->{$key} } ; $i++ ) {
                ##! 256: 'i: ' . $i
                if ( ref $entry->{$key}->[$i] eq 'HASH' ) {
                    if ( exists $entry->{$key}->[$i]->{'content'} ) {
                        ##! 256: 'entry #' . $i . ' has content key, flattening'
                        $entry->{$key}->[$i] =
                          $entry->{$key}->[$i]->{'content'};
                    }
                    else {
                        ##! 256: 'entry #' . $i . ' does not have content key'
                        ##! 512: ref $entry->{$key}->[$i]
                        if ( ref $entry->{$key}->[$i] eq 'HASH' ) {

                            # no need to flatten scalars any more
                            ##! 256: 'recursively flattening more ...'
                            $entry->{$key}->[$i] =
                              __flatten_content( $entry->{$key}->[$i],
                                $force_array );
                        }
                    }
                }
            }
        }
    }
    return $entry;
}

my $workflow_config = {

    # how we name it in our XML configuration file
    workflows => {

        # how the parameter is called for Workflow::Factory
        factory_param => 'workflow',

        # if this key exists, we assume that no <configfile>
        # is specified but the XML config is included directly
        # and iterate over it to obtain the configuration which
        # we pass to Workflow::Factory->add_config()
        config_key => 'workflow',

        # the ForceArray XML::Simple option used in Workflow
        # that we have to recreate using __flatten_content()
        # the content is taken from Workflow::Config::XML
        force_array => [
            'extra_data', 'state', 'action', 'resulting_state',
            'condition',  'observer'
        ],
    },
    activities => {
        factory_param => 'action',
        config_key    => 'actions',

        # if this key is present, we iterate over two levels:
        # first over all config_keys and then over all
        # config_iterators and add the corresponding structure
        # to the Workflow factory using add_config()
        config_iterator => 'action',
        force_array =>
          [ 'action', 'field', 'source_list', 'param', 'validator', 'arg' ],
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

my $workflow_factory = OpenXPKI::Workflow::Factory->new();

foreach my $type (qw( conditions validators activities workflows )) {

    ##! 64: "Setup $type"
    my @base_path =
      ( 'workflow_config', $type, $workflow_config->{$type}->{config_key}, );
    my @base_ctr = ( 0, 0 );

    my $toplevel_count = 0;
    eval {
        $toplevel_count = $xml_config->get_xpath_count(
            XPATH   => [@base_path],
            COUNTER => [ 0, 0 ],
        );
    };
    ##! 64: "Toplevel Count is $toplevel_count on " . join "-", @base_path
    for ( my $ii = 0 ; $ii < $toplevel_count ; $ii++ ) {

        if ( exists $workflow_config->{$type}->{'config_iterator'} ) {

            # we need to iterate over a second level
            my $iterator = $workflow_config->{$type}->{'config_iterator'};

            my $secondlevel_count = 0;
            eval {
                $secondlevel_count = $xml_config->get_xpath_count(
                    XPATH   => [ @base_path, $iterator ],
                    COUNTER => [ @base_ctr,  $ii ],
                );
            };
            ##! 16: 'secondlevel_count: ' . $secondlevel_count
            for ( my $iii = 0 ; $iii < $secondlevel_count ; $iii++ ) {
                my $entry = $xml_config->get_xpath_hashref(
                    XPATH   => [ @base_path, $iterator ],
                    COUNTER => [ @base_ctr,  $ii, $iii ],
                );
                ##! 32: 'entry ' . $iii . ': ' . Dumper $entry
                # '__flatten_content()' turns our XMLin
                # structure into the one compatible to Workflow

                $workflow_factory->add_config(
                    $workflow_config->{$type}->{factory_param} =>
                      __flatten_content(
                        $entry, $workflow_config->{$type}->{'force_array'}
                      ),
                );
                ##! 256: 'workflow_factory: ' . Dumper $workflow_factory
            }
        }    # else iterator
        else {
            my $entry = $xml_config->get_xpath_hashref(
                XPATH   => [@base_path],
                COUNTER => [ @base_ctr, $ii ],
            );
            ##! 32: "entry: " . Dumper $entry
            # Flatten some attributes because
            # Workflow.pm expects these to be scalars and not
            # a one-element arrayref with a content hashref ...
            $entry =
              __flatten_content( $entry,
                $workflow_config->{$type}->{force_array} );
            ##! 256: 'entry after flattening: ' . Dumper $entry
            ##! 512: 'workflow_factory: ' . Dumper $workflow_factory
            $workflow_factory->add_config(
                $workflow_config->{$type}->{factory_param} => $entry, );
            ##! 256: 'workflow_factory: ' . Dumper $workflow_factory
        }
    }
}

if ($wf_type  && !$workflow_factory->{_workflow_config}->{$wf_type}) {
    print "Given workflow type -$wf_type- not known in config!\n";
}

if (!$wf_type) {
    print "Give workflow to convert as second argument:\n\n ";
    print join "\n ", keys %{$workflow_factory->{_workflow_config}};
    print "\n";
    exit 1;
}

my $out     = {
    head      => {},
    state     => {},
    action    => {},
    condition => {},
    validator => {},
    field     => {},
    acl       => {
        Anonymous => { creator => 'self' },
        System => { creator => 'self' },
        User => { creator => 'self' },
        'RA Operator' => { creator => 'any' },
        'CA Operator' => { creator => 'any' },
    }
};
my @wf = @{ $workflow_factory->{_workflow_config}->{$wf_type}->{state} };

my $prefix = substr( sha1_hex($wf_type), 0, 6 );

$out->{head} = {
    label  => $wf_type,
    prefix => $prefix,
    description => $wf_type.'_DESC',
};

my $actions = $workflow_factory->{_action_config}->{default};

my $polist = {};

foreach my $state (@wf) {

    my $i18n = sprintf('I18N_OPENXPKI_UI_WORKFLOW_STATE_%s_%s_', uc($prefix), uc($state->{name}));

    my @action;
    foreach my $act ( @{ $state->{action} } ) {

        # array of hashes, condition in key "name"
        my @cond;
        if ( $act->{condition} ) {
            @cond = map { ( $_->{name} ) } @{ $act->{condition} };
        }
        push @action,
          $act->{name} . ' > '
          . $act->{resulting_state}
          . ( @cond ? ' ? ' . join( " ", @cond ) : '' );

        # Add action
        my $action_name = $act->{name};
        if (!$out->{action}->{ $action_name }) {
            my @validator;
            my @fields;
            foreach my $field (@{$actions->{ $act->{name} }->{field}}) {
                push @fields, $field->{name};
                my $i18n = sprintf('I18N_OPENXPKI_UI_WORKFLOW_FIELD_%s_', uc($field->{name}));
                if (!$out->{field}->{ $field->{name} }) {
                    $out->{field}->{ $field->{name} } = {
                        name => $field->{name},
                        required => ($field->{is_required} && $field->{is_required} =~ /yes/) ? 1 : 0,
                        label => $i18n.'LABEL',
                        description => $i18n.'DESC',
                        placeholder => $i18n.'PLACEHOLDER',
                        tooltip  => $i18n.'TOOLTIP',
                        type => $field->{type} ? $field->{type} : 'text'
                    };
                    $polist->{ $i18n.'LABEL' } = $field->{name};
                }
            }

            foreach my $field (@{$actions->{ $act->{name} }->{validator}}) {
                push @validator, $field->{name};
                if (!$out->{validator}->{ $field->{name} }) {
                    my $val = $workflow_factory->{_validator_config}->{ $field->{name} };
                    my $valdef = {
                        class => $val->{class},
                        param => {}
                    };
                    if ($field->{arg}) {
                        $valdef->{arg} = $field->{arg};
                    }

                    foreach my $p (keys %{$val}) {
                        next if ($p =~ /class|name/);
                        $valdef->{param}->{$p} = $val->{$p};
                    }
                    $out->{validator}->{ $field->{name} } = $valdef;
                }
            }

            my %aparam;

            %aparam = %{$actions->{ $act->{name} }};
            foreach my $del (qw(name class validator field)) { delete $aparam{$del}; }

            # Quote param values starting with TT delimiters
            map { $aparam{$_} = '"'.$aparam{$_}.'"' if ($aparam{$_} =~ /^\[/); } keys %aparam;

            my $i18n = sprintf('I18N_OPENXPKI_UI_WORKFLOW_ACTION_%s_', uc($action_name));

            $out->{action}->{ $action_name } = {
                class       => $actions->{ $act->{name} }->{class},
                label       => $i18n.'LABEL',
                description => $i18n.'DESC',
                input => \@fields,
                validator => \@validator,
                param => \%aparam,
            };

            $out->{action}->{ $action_name }->{uihandle} = $actions->{ $act->{name} }->{uihandle}  if ($actions->{ $act->{name} }->{uihandle});

            $polist->{ $i18n.'LABEL' } = $act->{name};
            $polist->{ $i18n.'LABEL' } = $actions->{ $act->{name} }->{label} if ($actions->{ $act->{name} }->{label});
            $polist->{ $i18n.'DESC' } = $actions->{ $act->{name} }->{description} if ($actions->{ $act->{name} }->{description});
        }

        # Define conditions
        foreach my $cond (@cond) {
            next unless $cond;
            $cond =~ s/^!//;
            if (!$out->{condition}->{ $cond }) {
                my $cd = $workflow_factory->{_condition_config}->{default}->{ $cond };
                my %params = %{$cd};
                delete $params{class};
                delete $params{name};
                $out->{condition}->{ $cond } = {
                    class => $cd->{class},
                    param => \%params
                }
            }
        }

    }

    my $item = {
        label       => $i18n.'LABEL',
        description => $i18n.'DESC',
    };

    #autorun: 0/1
    if ($state->{autorun} =~ /(yes|1)/) {
        $item->{autorun} = 1;
    }

    $polist->{ $i18n.'LABEL' } = $state->{label} if ($state->{label});
    $polist->{ $i18n.'DESC' } = $state->{description} if ($state->{description});

    if (@action) {
        $item->{action} = \@action;
    }

    $out->{state}->{ $state->{name} } = $item;

}

foreach my $node (qw(head  state  action condition validator field acl)) {
    if ( %{ $out->{$node} } ) {
        _write( $node.':', $out->{$node} );
        push @yaml, "";
    }
}

if (!$target) {
    print join "\n", @yaml;
} else {

    if (-d $target) {
        $wf_type =~ s/I18N_OPENXPKI_WF_TYPE_//;
        $wf_type = lc($wf_type);
        open(FP, ">$target/$wf_type.yaml") || die "Unable to open target file";
    } else {
        open(FP, ">$target") || die "Unable to open target file";
    }
    print FP join "\n", @yaml;
    close (FP);
}


#print "\n###################PO Block###################\n\n";
foreach my $i18n (sort keys %{$polist}) {
    #printf qq("%s"\n"%s"\n\n), $i18n, $polist->{$i18n};
}
