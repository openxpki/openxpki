## OpenXPKI::Server::API::Default.pm 
## (was once the main part of OpenXPKI::Server::API)
##
## Written 2005 by Michael Bell and Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project
package OpenXPKI::Server::API::Default;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

use Data::Dumper;

#use Regexp::Common;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::i18n qw( set_language );
use Digest::SHA1 qw( sha1_base64 );
use DateTime;

use Workflow;

sub START {
    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED',
    );
}
# API: simple retrieval functions

sub count_my_certificates {
    ##! 1: 'start'

    my $certs = CTX('api')->list_my_certificates();
    ##! 1: 'end'
    return scalar @{ $certs };
}

sub list_my_certificates {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    my $user  = CTX('session')->get_user();
    my $realm = CTX('session')->get_pki_realm();

    my %limit = ();

    if (exists $arg_ref->{LIMIT}) {
        $limit{LIMIT}->{AMOUNT} = $arg_ref->{LIMIT};
    }
    if (exists $arg_ref->{START}) {
        $limit{LIMIT}->{START}  = $arg_ref->{START};
    }
    my @results;
    my $db_results = CTX('dbi_backend')->select(
        TABLE => [
            [ 'WORKFLOW_CONTEXT' => 'context1' ],
            [ 'WORKFLOW_CONTEXT' => 'context2' ],
            [ 'WORKFLOW_CONTEXT' => 'context3' ],
            'CERTIFICATE',
        ],
        COLUMNS => [
            'CERTIFICATE.NOTBEFORE',
            'CERTIFICATE.NOTAFTER',
            'CERTIFICATE.IDENTIFIER',
            'CERTIFICATE.SUBJECT',
            'CERTIFICATE.STATUS',
            'CERTIFICATE.CERTIFICATE_SERIAL',
        ],
        DYNAMIC => {
            'context1.WORKFLOW_CONTEXT_KEY'   => 'workflow_parent_id',
            'context2.WORKFLOW_CONTEXT_KEY'   => 'creator',
            'context3.WORKFLOW_CONTEXT_KEY'   => 'cert_identifier',
            'context2.WORKFLOW_CONTEXT_VALUE' => $user,
            'CERTIFICATE.PKI_REALM'           => $realm,
        },
        JOIN => [
            [
                'WORKFLOW_CONTEXT_VALUE',
                'WORKFLOW_SERIAL',
                undef,
                undef,
            ],
            [
                undef,
                undef,
                'WORKFLOW_CONTEXT_VALUE',
                'IDENTIFIER',
            ],
            [
                'WORKFLOW_SERIAL',
		undef,
                'WORKFLOW_SERIAL',
                undef,
            ],
        ],
        REVERSE => 1,
        DISTINCT => 1,
        %limit,
    );
    foreach my $entry (@{ $db_results }) {
        ##! 16: 'entry: ' . Dumper \$entry
        my $temp_hash = {};
        foreach my $key (keys %{ $entry }) {
            my $orig_key = $key;
            ##! 16: 'key: ' . $key
            $key =~ s{ \A CERTIFICATE\. }{}xms;
            ##! 16: 'key: ' . $key
            $temp_hash->{$key} = $entry->{$orig_key};
        }
        push @results, $temp_hash;
    }
    ##! 64: 'results: ' . Dumper \@results
    ##! 1: 'end'

    return \@results;
}

sub get_cert_identifier {
    ##! 1: 'start'
    my $self      = shift;
    my $arg_ref   = shift;
    my $cert      = $arg_ref->{CERT};
    my $pki_realm = CTX('session')->get_pki_realm();
    my $default_token = CTX('pki_realm')->{$pki_realm}->{crypto}->{default};
    ##! 64: 'cert: ' . $cert

    my $x509 = OpenXPKI::Crypto::X509->new(
        DATA  => $cert,
        TOKEN => $default_token,
    );

    my $identifier = $x509->get_identifier();
    ##! 4: 'identifier: ' . $identifier

    ##! 1: 'end'
    return $identifier;
}

sub get_workflow_ids_for_cert {
    my $self    = shift;
    my $arg_ref = shift;
    my $csr_serial = $arg_ref->{'CSR_SERIAL'};

    my $workflow_ids = CTX('api')->search_workflow_instances(
        {
            CONTEXT => [
                {
                    KEY   => 'csr_serial',
                    VALUE => $csr_serial,
                },
            ],
            TYPE => [
                'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
                'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_ISSUANCE'
            ]
        }
    );

    return $workflow_ids;
}

sub get_current_config_id {
    my $self = shift;
    return CTX('xml_config')->get_current_config_id();
}

sub list_config_ids {
    my $self = shift;
    ##! 1: 'start'
    my $config_entries = CTX('dbi_backend')->select(
        TABLE   => 'CONFIG',
        DYNAMIC => {
            CONFIG_IDENTIFIER => '%',
        },
    );
    if (! defined $config_entries
        || ref $config_entries ne 'ARRAY'
        || scalar @{ $config_entries } == 0) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_LIST_CONFIG_IDS_NO_CONFIG_IDS_IN_DB',
        );
    }
    ##! 64: 'config_entries: ' . Dumper $config_entries

    my @config_ids = map { $_->{CONFIG_IDENTIFIER} } @{ $config_entries };
    return \@config_ids;
}

sub get_cert_subject_styles {
    my $self      = shift;
    my $arg_ref   = shift;
    my $profile   = $arg_ref->{PROFILE};
    my $cfg_id    = $arg_ref->{CONFIG_ID};
    my $pkcs10    = $arg_ref->{PKCS10};
    ##! 1: 'start'

    my $csr_info;
    if (defined $pkcs10) {
        # if PKCS#10 data is passed, we need to get the info from
        # the data ...
        ##! 16: 'pkcs10 defined'
        $csr_info = CTX('api')->get_csr_info_hash_from_data({
            DATA => $pkcs10,
        });
        ##! 64: 'csr info: ' . Dumper $csr_info
    }

    my $pki_realm = CTX('session')->get_pki_realm();
    my $index         = $self->get_pki_realm_index({
        CONFIG_ID => $cfg_id,
    });
    my $profile_index = $self->__get_profile_index({
        PROFILE   => $profile,
        CONFIG_ID => $cfg_id,
    });
    my $styles = {};
    my @base_path = ( 'pki_realm', 'common', 'profiles', 'endentity', 'profile' );
    my @base_ctr  = ( $index     , 0       , 0         , 0          , $profile_index );

    my $count = 0;
    eval {
        $count = CTX('xml_config')->get_xpath_count(
            XPATH     => [ @base_path, 'subject' ],
            COUNTER   => [ @base_ctr ],
            CONFIG_ID => $cfg_id,
        );
    };
    ##! 16: 'count: ' . $count
    # iterate over all subject styles
    for (my $i = 0; $i < $count; $i++) {
        my $id = CTX('xml_config')->get_xpath(
            XPATH     => [ @base_path, 'subject', 'id' ],
            COUNTER   => [ @base_ctr , $i       , 0    ],
            CONFIG_ID => $cfg_id,
        );
        ##! 64: 'id: ' . $id
        $styles->{$id}->{LABEL} = CTX('xml_config')->get_xpath(
            XPATH     => [ @base_path, 'subject', 'label' ],
            COUNTER   => [ @base_ctr , $i       , 0       ],
            CONFIG_ID => $cfg_id,
        );
        ##! 64: 'label: ' . $styles->{$id}->{LABEL}
        $styles->{$id}->{DESCRIPTION} = CTX('xml_config')->get_xpath(
            XPATH     => [ @base_path, 'subject', 'description' ],
            COUNTER   => [ @base_ctr , $i       , 0             ],
            CONFIG_ID => $cfg_id,
        );
        ##! 64: 'description: ' . $styles->{$id}->{DESCRIPTION}
        $styles->{$id}->{DN} = CTX('xml_config')->get_xpath(
            XPATH     => [ @base_path, 'subject', 'dn' ],
            COUNTER   => [ @base_ctr , $i       , 0    ],
            CONFIG_ID => $cfg_id,
        );
        ##! 64: 'dn: ' . $styles->{$id}->{DN}

        my $bulk;
        eval {
            $bulk = CTX('xml_config')->get_xpath(
                XPATH      => [ @base_path, 'subject', 'bulk' ],
                COUNTER    => [ @base_ctr,  $i       , 0      ],
                CONFIG_ID  => $cfg_id,
            );
        };
        if ($bulk) {
            ##! 16: 'bulk defined for this style'
            $styles->{$id}->{BULK} = 1;
        }

        my $input_count = 0;
        eval {
            $input_count = CTX('xml_config')->get_xpath_count(
               XPATH     => [ @base_path, 'subject', 'template', 'input' ],
               COUNTER   => [ @base_ctr , $i       , 0        ],
               CONFIG_ID => $cfg_id,
            );
        };
        ##! 64: 'input count: ' . $input_count

        # iterate over all subject input definitions
        for (my $ii = 0; $ii < $input_count; $ii++) {
            my @input_path = @base_path;
            push @input_path, ( 'subject', 'template', 'input' );
            my @input_ctr  = @base_ctr;
            push @input_ctr,  ( $i       , 0         , $ii     );

            $styles->{$id}->{TEMPLATE}->{INPUT}->[$ii]->{ID} = CTX('xml_config')->get_xpath(
                XPATH     => [ @input_path, 'id' ],
                COUNTER   => [ @input_ctr , 0    ],
                CONFIG_ID => $cfg_id,
            );
            $styles->{$id}->{TEMPLATE}->{INPUT}->[$ii]->{LABEL} = CTX('xml_config')->get_xpath(
                XPATH     => [ @input_path, 'label' ],
                COUNTER   => [ @input_ctr , 0    ],
                CONFIG_ID => $cfg_id,
            );
            $styles->{$id}->{TEMPLATE}->{INPUT}->[$ii]->{DESCRIPTION} = CTX('xml_config')->get_xpath(
                XPATH     => [ @input_path, 'description' ],
                COUNTER   => [ @input_ctr , 0    ],
                CONFIG_ID => $cfg_id,
            );
            $styles->{$id}->{TEMPLATE}->{INPUT}->[$ii]->{TYPE} = CTX('xml_config')->get_xpath(
                XPATH     => [ @input_path, 'type' ],
                COUNTER   => [ @input_ctr , 0    ],
                CONFIG_ID => $cfg_id,
            );
            # source, min, max, match, width and default are optional,
            # thus in eval
            eval {
                $styles->{$id}->{TEMPLATE}->{INPUT}->[$ii]->{SOURCE} = CTX('xml_config')->get_xpath(
                    XPATH     => [ @input_path, 'source' ],
                    COUNTER   => [ @input_ctr , 0    ],
                    CONFIG_ID => $cfg_id,
                );
            };
            eval {
                $styles->{$id}->{TEMPLATE}->{INPUT}->[$ii]->{MIN} = CTX('xml_config')->get_xpath(
                    XPATH     => [ @input_path, 'min' ],
                    COUNTER   => [ @input_ctr , 0    ],
                    CONFIG_ID => $cfg_id,
                );
            };
            eval {
                $styles->{$id}->{TEMPLATE}->{INPUT}->[$ii]->{MAX} = CTX('xml_config')->get_xpath(
                    XPATH     => [ @input_path, 'max' ],
                    COUNTER   => [ @input_ctr , 0    ],
                    CONFIG_ID => $cfg_id,
                );
            };
            eval {
                $styles->{$id}->{TEMPLATE}->{INPUT}->[$ii]->{MATCH} = CTX('xml_config')->get_xpath(
                    XPATH     => [ @input_path, 'match' ],
                    COUNTER   => [ @input_ctr , 0    ],
                    CONFIG_ID => $cfg_id,
                );
            };
            eval {
                $styles->{$id}->{TEMPLATE}->{INPUT}->[$ii]->{WIDTH} = CTX('xml_config')->get_xpath(
                    XPATH     => [ @input_path, 'width' ],
                    COUNTER   => [ @input_ctr , 0    ],
                    CONFIG_ID => $cfg_id,
                );
            };
            eval {
                $styles->{$id}->{TEMPLATE}->{INPUT}->[$ii]->{DEFAULT} = CTX('xml_config')->get_xpath(
                    XPATH     => [ @input_path, 'default' ],
                    COUNTER   => [ @input_ctr , 0    ],
                    CONFIG_ID => $cfg_id,
                );
            };

            if (defined $pkcs10) {
                # if a PKCS#10 is passed, we want to try and set the
                # default value from the data available within the
                # PKCS#10 file ...
                my $source;
                eval {
                    $source = CTX('xml_config')->get_xpath(
                        XPATH     => [ @input_path, 'source' ],
                        COUNTER   => [ @input_ctr , 0        ],
                        CONFIG_ID => $cfg_id,
                    );
                };
                ##! 16: 'source: ' . $source
                # if source is defined, use it with $csr_info ...
                if (defined $source) {
                    my ($part, $regex) = ($source =~ m{([^:]+) : (.+)}xms);
                    ##! 16: 'part: ' . $part
                    ##! 16: 'regex: ' . $regex
                    my $part_from_csr;
                    eval {
                        # try to get data from csr info hash
                        # currently, we only get the first entry
                        # for the given part (so we can not deal
                        # with multiple OUs, for example)
                        $part_from_csr = $csr_info->{BODY}->{SUBJECT_HASH}->{$part}->[0];
                    };
                    ##! 16: 'part from csr: ' . $part_from_csr
                    if (defined $part_from_csr) {
                        my ($match) = ($part_from_csr =~ m{$regex}xms);
                        ##! 16: 'match: ' . $match
                        # override default value with the result of the
                        # regex matching
                        $styles->{$id}->{TEMPLATE}->{INPUT}->[$ii]->{DEFAULT} = $match;
                    }
                }
            }
            # if type is select, add options array ref
            if ($styles->{$id}->{TEMPLATE}->{INPUT}->[$ii]->{TYPE} eq 'select') {
                ##! 64: 'type is select'
                my $options_count = CTX('xml_config')->get_xpath_count(
                    XPATH     => [ @input_path, 'option' ],
                    COUNTER   => [ @input_ctr ],
                    CONFIG_ID => $cfg_id,
                );
                ##! 64: 'options_count: ' . $options_count
                for (my $iii = 0; $iii < $options_count; $iii++) {
                    $styles->{$id}->{TEMPLATE}->{INPUT}->[$ii]->{OPTIONS}->[$iii] = CTX('xml_config')->get_xpath(
                        XPATH     => [ @input_path, 'option' ],
                        COUNTER   => [ @input_ctr , $iii     ],
                        CONFIG_ID => $cfg_id,
                    ); 
                }
            }
        }

        my $add_input_count = 0;
        eval {
            $add_input_count = CTX('xml_config')->get_xpath_count(
                XPATH     => [ @base_path, 'subject', 'additional_information', 'input' ],
                COUNTER   => [ @base_ctr , $i       , 0        ],
                CONFIG_ID => $cfg_id,
            );
        };
        ##! 64: 'additional input count: ' . $add_input_count

        # iterate over all additional information input definitions        
        for (my $ii = 0; $ii < $add_input_count; $ii++) {
            my @input_path = @base_path;
            push @input_path, ( 'subject', 'additional_information', 'input' );
            my @input_ctr  = @base_ctr;
            push @input_ctr,  ( $i       , 0         , $ii     );

            $styles->{$id}->{ADDITIONAL_INFORMATION}->{INPUT}->[$ii]->{ID} = CTX('xml_config')->get_xpath(
                XPATH     => [ @input_path, 'id' ],
                COUNTER   => [ @input_ctr , 0    ],
                CONFIG_ID => $cfg_id,
            );
            $styles->{$id}->{ADDITIONAL_INFORMATION}->{INPUT}->[$ii]->{LABEL} = CTX('xml_config')->get_xpath(
                XPATH     => [ @input_path, 'label' ],
                COUNTER   => [ @input_ctr , 0    ],
                CONFIG_ID => $cfg_id,
            );
            $styles->{$id}->{ADDITIONAL_INFORMATION}->{INPUT}->[$ii]->{DESCRIPTION} = CTX('xml_config')->get_xpath(
                XPATH     => [ @input_path, 'description' ],
                COUNTER   => [ @input_ctr , 0    ],
                CONFIG_ID => $cfg_id,
            );
            $styles->{$id}->{ADDITIONAL_INFORMATION}->{INPUT}->[$ii]->{TYPE} = CTX('xml_config')->get_xpath(
                XPATH     => [ @input_path, 'type' ],
                COUNTER   => [ @input_ctr , 0    ],
                CONFIG_ID => $cfg_id,
            );
            # width, height, default is optional,
            # thus in eval
            eval {
                $styles->{$id}->{ADDITIONAL_INFORMATION}->{INPUT}->[$ii]->{WIDTH} = CTX('xml_config')->get_xpath(
                    XPATH     => [ @input_path, 'width' ],
                    COUNTER   => [ @input_ctr , 0    ],
                    CONFIG_ID => $cfg_id,
                );
            };
            eval {
                $styles->{$id}->{ADDITIONAL_INFORMATION}->{INPUT}->[$ii]->{HEIGHT} = CTX('xml_config')->get_xpath(
                    XPATH     => [ @input_path, 'height' ],
                    COUNTER   => [ @input_ctr , 0    ],
                    CONFIG_ID => $cfg_id,
                );
            };
            eval {
                $styles->{$id}->{ADDITIONAL_INFORMATION}->{INPUT}->[$ii]->{DEFAULT} = CTX('xml_config')->get_xpath(
                    XPATH     => [ @input_path, 'default' ],
                    COUNTER   => [ @input_ctr , 0    ],
                    CONFIG_ID => $cfg_id,
                );
            };
            # if type is select, add options array ref
            if ($styles->{$id}->{ADDITIONAL_INFORMATION}->{INPUT}->[$ii]->{TYPE} eq 'select') {
                ##! 64: 'type is select'
                my $options_count = CTX('xml_config')->get_xpath_count(
                    XPATH     => [ @input_path, 'option' ],
                    COUNTER   => [ @input_ctr ],
                    CONFIG_ID => $cfg_id,
                );
                ##! 64: 'options_count: ' . $options_count
                for (my $iii = 0; $iii < $options_count; $iii++) {
                    $styles->{$id}->{ADDITIONAL_INFORMATION}->{INPUT}->[$ii]->{OPTIONS}->[$iii] = CTX('xml_config')->get_xpath(
                        XPATH     => [ @input_path, 'option' ],
                        COUNTER   => [ @input_ctr , $iii     ],
                        CONFIG_ID => $cfg_id,
                    ); 
                }
            }
        }

        my $san_count = 0;
        eval {
            $san_count = CTX('xml_config')->get_xpath_count(
                XPATH     => [ @base_path, 'subject', 'subject_alternative_names', 'san' ],
                COUNTER   => [ @base_ctr , $i       , 0        ],
                CONFIG_ID => $cfg_id,
            );
        };
        
        # iterate over all subject alternative name definitions
        for (my $ii = 0; $ii < $san_count; $ii++) {
            my @san_path = @base_path;
            push @san_path, ( 'subject', 'subject_alternative_names', 'san' );
            my @san_ctr  = @base_ctr;
            push @san_ctr,  ( $i       , 0         , $ii     );

            $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{ID} = CTX('xml_config')->get_xpath(
                XPATH     => [ @san_path, 'id' ],
                COUNTER   => [ @san_ctr , 0     ],
                CONFIG_ID => $cfg_id,
            );
            my $key_type = CTX('xml_config')->get_xpath(
                XPATH     => [ @san_path, 'key', 'type' ],
                COUNTER   => [ @san_ctr , 0    , 0      ],
                CONFIG_ID => $cfg_id,
            );
            $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{KEY}->{TYPE} = $key_type;
            # depending on the key type, different configs need to be read
            if ($key_type eq 'fixed') {
                $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{KEY}->{VALUE} = CTX('xml_config')->get_xpath(
                    XPATH     => [ @san_path, 'key' ],
                    COUNTER   => [ @san_ctr , 0     ],
                    CONFIG_ID => $cfg_id,
                );
            }
            elsif ($key_type eq 'select') {
                # get all options
                my $san_opt_count = 0;
                eval {
                    $san_opt_count = CTX('xml_config')->get_xpath_count(
                        XPATH     => [ @san_path, 'key', 'option' ],
                        COUNTER   => [ @san_ctr , 0    , 0     ],
                        CONFIG_ID => $cfg_id,
                    );
                };
                ##! 64: 'san_opt_count: ' . $san_opt_count
    
                # iterate over all SAN key options
                for (my $iii = 0; $iii < $san_opt_count; $iii++) {
                    $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{KEY}->{OPTIONS}->[$iii]->{LABEL} = CTX('xml_config')->get_xpath(
                        XPATH     => [ @san_path, 'key', 'option', 'label' ],
                        COUNTER   => [ @san_ctr , 0    , $iii    , 0       ],
                        CONFIG_ID => $cfg_id,
                    );
                    $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{KEY}->{OPTIONS}->[$iii]->{DESCRIPTION} = CTX('xml_config')->get_xpath(
                        XPATH     => [ @san_path, 'key', 'option', 'description' ],
                        COUNTER   => [ @san_ctr , 0    , $iii    , 0       ],
                        CONFIG_ID => $cfg_id,
                    );
                    $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{KEY}->{OPTIONS}->[$iii]->{VALUE} = CTX('xml_config')->get_xpath(
                        XPATH     => [ @san_path, 'key', 'option' ],
                        COUNTER   => [ @san_ctr , 0    , $iii     ],
                        CONFIG_ID => $cfg_id,
                    );
                }
                # min and max are optional
                eval {
                    $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{KEY}->{MIN} = CTX('xml_config')->get_xpath(
                        XPATH     => [ @san_path, 'key', 'min' ],
                        COUNTER   => [ @san_ctr , 0    , 0     ],
                        CONFIG_ID => $cfg_id,
                    );
                };
                eval {
                    $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{KEY}->{MAX} = CTX('xml_config')->get_xpath(
                        XPATH     => [ @san_path, 'key', 'max' ],
                        COUNTER   => [ @san_ctr , 0    , 0     ],
                        CONFIG_ID => $cfg_id,
                    );
                };
            }
            elsif ($key_type eq 'oid') {
                # min, max and width are optional
                eval {
                    $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{KEY}->{MIN} = CTX('xml_config')->get_xpath(
                        XPATH     => [ @san_path, 'key', 'min' ],
                        COUNTER   => [ @san_ctr , 0    , 0     ],
                        CONFIG_ID => $cfg_id,
                    );
                };
                eval {
                    $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{KEY}->{MAX} = CTX('xml_config')->get_xpath(
                        XPATH     => [ @san_path, 'key', 'max' ],
                        COUNTER   => [ @san_ctr , 0    , 0     ],
                        CONFIG_ID => $cfg_id,
                    );
                };
                eval {
                    $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{KEY}->{WIDTH} = CTX('xml_config')->get_xpath(
                        XPATH     => [ @san_path, 'key', 'width' ],
                        COUNTER   => [ @san_ctr , 0    , 0     ],
                        CONFIG_ID => $cfg_id,
                    );
                };
            }
            my $value_type = CTX('xml_config')->get_xpath(
                XPATH     => [ @san_path, 'value', 'type' ],
                COUNTER   => [ @san_ctr , 0    , 0        ],
                CONFIG_ID => $cfg_id,
            );
            $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{VALUE}->{TYPE} = $value_type;
            if ($value_type eq 'fixed') {
                $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{VALUE}->{TEMPLATE} = CTX('xml_config')->get_xpath(
                    XPATH     => [ @san_path, 'value' ],
                    COUNTER   => [ @san_ctr , 0       ],
                    CONFIG_ID => $cfg_id,
                );
            }
            elsif ($value_type eq 'freetext') {
                # width is optional
                eval {
                    $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{VALUE}->{WIDTH} = CTX('xml_config')->get_xpath(
                        XPATH     => [ @san_path, 'value', 'width' ],
                        COUNTER   => [ @san_ctr , 0    , 0     ],
                        CONFIG_ID => $cfg_id,
                    );
                };
            }
            elsif ($value_type eq 'select') {
                my $san_opt_count = 0;
                eval {
                    $san_opt_count = CTX('xml_config')->get_xpath_count(
                        XPATH     => [ @san_path, 'value', 'option' ],
                        COUNTER   => [ @san_ctr , 0    , 0     ],
                        CONFIG_ID => $cfg_id,
                    );
                };
                ##! 64: 'san_opt_count: ' . $san_opt_count
    
                # iterate over all SAN key options
                for (my $iii = 0; $iii < $san_opt_count; $iii++) {
                    $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{VALUE}->{OPTIONS}->[$iii]->{LABEL} = CTX('xml_config')->get_xpath(
                        XPATH     => [ @san_path, 'value', 'option', 'label' ],
                        COUNTER   => [ @san_ctr , 0    , $iii    , 0       ],
                        CONFIG_ID => $cfg_id,
                    );
                    $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{VALUE}->{OPTIONS}->[$iii]->{VALUE} = CTX('xml_config')->get_xpath(
                        XPATH     => [ @san_path, 'value', 'option' ],
                        COUNTER   => [ @san_ctr , 0    , $iii     ],
                        CONFIG_ID => $cfg_id,
                    );
                }
                # min and max are optional
                eval {
                    $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{VALUE}->{MIN} = CTX('xml_config')->get_xpath(
                        XPATH     => [ @san_path, 'value', 'min' ],
                        COUNTER   => [ @san_ctr , 0    , 0     ],
                        CONFIG_ID => $cfg_id,
                    );
                };
                eval {
                    $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{VALUE}->{MAX} = CTX('xml_config')->get_xpath(
                        XPATH     => [ @san_path, 'value', 'max' ],
                        COUNTER   => [ @san_ctr , 0    , 0     ],
                        CONFIG_ID => $cfg_id,
                    );
                };
            }
        }
        if ($pkcs10) {
            # add subject alternative names from CSR if present
            my @pkcs10_sans = ();

	    my $tmp = $csr_info->{BODY}->{OPENSSL_EXTENSIONS}->{'X509v3 Subject Alternative Name'}->[0];
	    if (defined $tmp) {
		eval {
		    @pkcs10_sans = split q{, }, $tmp;
		};
	    }
	    for (my $ii = $san_count; $ii < ($san_count + scalar @pkcs10_sans); $ii++) {
                # add fixed SAN entries for all SANs in the PKCS#10
                my $san = $pkcs10_sans[$ii - $san_count];
                ##! 16: 'san: ' . $san
                my ($key, $value) = ($san =~ m{([^:]+) : (.+)}xms);
                ##! 16: 'key: ' . $key
                ##! 16: 'value: ' . $value
                $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{ID} = 'pkcs10' . ($ii - $san_count);
                $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{KEY}->{TYPE} = 'fixed';
                $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{KEY}->{VALUE} = $key;
                $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{VALUE}->{TYPE} = 'fixed';
                $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES}->[$ii]->{VALUE}->{TEMPLATE} = $value;
            }
            ##! 16: '@pkcs10_sans: ' . Dumper \@pkcs10_sans
        }
    }
    ##! 128: 'styles: ' . Dumper $styles
    return $styles;
}

sub get_additional_information_fields {
    my $self      = shift;
    my $arg_ref   = shift;
    my $cfg_id    = $arg_ref->{CONFIG_ID};
#    my $profile   = $arg_ref->{PROFILE};
    ##! 1: 'start'

    my $pki_realm = CTX('session')->get_pki_realm();
    my $index         = $self->get_pki_realm_index({
        CONFIG_ID => $cfg_id,
    });


    my $styles = {};
    my @base_path = ( 'pki_realm', 'common', 'profiles', 'endentity', 'profile' );
    my @base_ctr  = ( $index     , 0       , 0         , 0           );

    my $profile_count = 
	CTX('xml_config')->get_xpath_count(
	    XPATH     => [ @base_path ],
	    COUNTER   => [ @base_ctr  ],
	    CONFIG_ID => $cfg_id,
	);

    ##! 16: 'identified ' . $profile_count . ' profiles'

    my $additional_information = {};

    # iterate through all profile and summarize all additional information
    # fields (may be redundant and even contradicting, but we only collect
    # the 'union' of these here; last one wins...)
    for (my $ii = 0; $ii < $profile_count; $ii++) {
	##! 16: 'profile # ' . $ii
	my $add_input_count = 0;
	eval {
	    $add_input_count = CTX('xml_config')->get_xpath_count(
		XPATH     => [ @base_path,           'subject', 'additional_information', 'input' ],
		COUNTER   => [ @base_ctr , $ii,      0,         0,        ],
		CONFIG_ID => $cfg_id,
		);
	};
	##! 64: 'additional input count: ' . $add_input_count
	foreach (my $jj = 0; $jj < $add_input_count; $jj++) {
            my @input_path = @base_path;
            push @input_path, (             'subject', 'additional_information', 'input' );
            my @input_ctr  = @base_ctr;
            push @input_ctr,  ( $ii,        0,         0,                        $jj     );
	    
	    
            my $id = CTX('xml_config')->get_xpath(
                XPATH     => [ @input_path, 'id' ],
                COUNTER   => [ @input_ctr , 0    ],
                CONFIG_ID => $cfg_id,
		);
            my $label = CTX('xml_config')->get_xpath(
                XPATH     => [ @input_path, 'label' ],
                COUNTER   => [ @input_ctr , 0    ],
                CONFIG_ID => $cfg_id,
		);

	    $additional_information->{ALL}->{$id} = $label;
	    ##! 16: "additional information: $id (label: $label)"
	}
    }


    return $additional_information;
}    

sub get_possible_profiles_for_role {
    my $self      = shift;
    my $arg_ref   = shift;
    my $req_role  = $arg_ref->{ROLE};
    my $cfg_id    = $arg_ref->{CONFIG_ID};
    ##! 1: 'start'
    ##! 16: 'requested role: ' . $req_role

    my $pki_realm = CTX('session')->get_pki_realm();
    my @profiles  = ();
    my $index     = $self->get_pki_realm_index({
        CONFIG_ID => $cfg_id,
    });

    my $count = CTX('xml_config')->get_xpath_count(
     XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile"],
     COUNTER => [$index     , 0       , 0         , 0],
     CONFIG_ID => $cfg_id,
    );
    ##! 16: 'count: ' . $count
    for (my $i=0; $i < $count; $i++) {
        my $id = CTX('xml_config')->get_xpath(
            XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "id"],
            COUNTER => [$index     , 0       , 0         , 0          , $i       , 0   ],
            CONFIG_ID => $cfg_id,
        );
        next if ($id eq "default");
        my $role_count = 0;
        eval {
            $role_count = CTX('xml_config')->get_xpath_count(
                XPATH   => ['pki_realm', 'common', 'profiles', 'endentity', 'profile', 'role'],
                COUNTER => [$index     , 0       , 0         , 0          , $i ],
                CONFIG_ID => $cfg_id,
            );
        };
        ##! 16: 'role_count: ' . $role_count
        foreach (my $ii = 0; $ii < $role_count; $ii++) {
            my $role = CTX('xml_config')->get_xpath(
                XPATH   => ['pki_realm', 'common', 'profiles', 'endentity', 'profile', 'role'],
                COUNTER => [$index     , 0       , 0         , 0          , $i       , $ii   ],
                CONFIG_ID => $cfg_id,
            );
            ##! 16: 'role: ' . $role
            if ($role eq $req_role) {
                ##! 16: 'requested role found, adding profile: ' . $id
                push @profiles, $id;
            }
        }
    }
    ##! 1: 'end'
    return \@profiles;
}

sub determine_issuing_ca {
    my $self = shift;
    my $arg_ref = shift;

    my $profilename = $arg_ref->{PROFILE};
    ##! 16: 'profilename: ' . $profilename

    my $cfg_id = $arg_ref->{CONFIG_ID};

    ##! 2: "get pki realm configuration"
    my $realms = CTX('pki_realm_by_cfg')->{$cfg_id}; 
    if (! defined $cfg_id) {
        $realms = CTX('pki_realm');
    }
    if (!(defined $realms && (ref $realms eq 'HASH'))) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_DETERMINE_ISSUING_CA_PKI_REALM_CONFIGURATION_UNAVAILABLE"
        );
    }

    ##! 2: "get session's realm"
    my $thisrealm = CTX('session')->get_pki_realm();
    ##! 2: "$thisrealm"
    if (! defined $thisrealm) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_DETERMINE_ISSUING_CA_PKI_REALM_NOT_SET"
	);
    }

    my $realm_config = CTX('pki_realm_by_cfg')->{$cfg_id}
                                              ->{$thisrealm};
    ##! 128: 'realm_config: ' . Dumper $realm_config

    if (! exists $realm_config->{endentity}->{id}->{$profilename}->{validity}) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_API_DETERMINE_ISSUING_CA_NO_MATCHING_PROFILE",
            params  => {
                REQUESTED_PROFILE => $profilename,
            },
        );
    }

    # get validity as specified in the configuration
    my $entry_validity 
	    = $realm_config->{endentity}->{id}->{$profilename}->{validity};

    my $requested_notbefore;
    my $requested_notafter;

    if (! exists $entry_validity->{notbefore}) {
        # assign default (current timestamp) if notbefore is not specified
        $requested_notbefore = DateTime->now( time_zone => 'UTC' );
    } else {
        $requested_notbefore = OpenXPKI::DateTime::get_validity(
            {
                VALIDITY => $entry_validity->{notbefore}->{validity},
                VALIDITYFORMAT => $entry_validity->{notbefore}->{format},
            },
        );
    }

    $requested_notafter = OpenXPKI::DateTime::get_validity(
	    {
            REFERENCEDATE => $requested_notbefore,
            VALIDITY => $entry_validity->{notafter}->{validity},
            VALIDITYFORMAT => $entry_validity->{notafter}->{format},
	    },
	);
    ##! 64: 'requested_notbefore: ' . Dumper $requested_notbefore
    ##! 64: 'request_notafter: ' . Dumper $requested_notafter


    # anticipate runtime differences, if the requested notafter is close
    # to the end a CA validity we might identify an issuing CA that is
    # not able to issue the certificate anymore when the actual signing
    # action begins
    # FIXME: is this acceptable?
    if ($entry_validity->{notafter}->{format} eq 'relativedate') {
        $requested_notafter->add( minutes => 5 );
    }        
    ##! 64: 'request_notafter (+5m?): ' . Dumper $requested_notafter

    # iterate through all issuing CAs and determine possible candidates
    # for issuing the requested certificate
    my $now = DateTime->now( time_zone => 'UTC' );
    my $intca;
    my $mostrecent_notbefore;
  CANDIDATE:
    foreach my $ca_id (sort keys %{ $realm_config->{ca}->{id} }) {
        ##! 16: 'ca_id: ' . $ca_id

        my $ca_notbefore = $realm_config->{ca}->{id}->{$ca_id}->{notbefore};
        ##! 16: 'ca_notbefore: ' . Dumper $ca_notbefore

        my $ca_notafter = $realm_config->{ca}->{id}->{$ca_id}->{notafter};
        ##! 16: 'ca_notafter: ' . Dumper $ca_notafter

        if (! defined $ca_notbefore || ! defined $ca_notafter) {
            ##! 16: 'ca_notbefore or ca_notafter undef, skipping'
            next CANDIDATE;
        }
        # check if issuing CA is valid now
        if (DateTime->compare($now, $ca_notbefore) < 0) {
            ##! 16: $ca_id . ' is not yet valid, skipping'
            next CANDIDATE;
        }
        if (DateTime->compare($now, $ca_notafter) > 0) {
            ##! 16: $ca_id . ' is expired, skipping'
            next CANDIDATE;
        }

        # check if requested validity fits into the ca validity
        if (DateTime->compare($requested_notbefore, $ca_notbefore) < 0) {
            ##! 16: 'requested notbefore does not fit in ca validity'
            next CANDIDATE;
        }
        if (DateTime->compare($requested_notafter, $ca_notafter) > 0) {
            ##! 16: 'requested notafter does not fit in ca validity'
            next CANDIDATE;
        }

        # check if this CA has a more recent NotBefore date
        if (defined $mostrecent_notbefore)
        {
            ##! 16: 'mostrecent_notbefore: ' . Dumper $mostrecent_notbefore
            if (DateTime->compare($ca_notbefore, $mostrecent_notbefore) > 0)
            {
                ##! 16: $ca_id . ' has an earlier notbefore data'
                $mostrecent_notbefore = $ca_notbefore;
                $intca = $ca_id;
            }
        }
        else
        {
            ##! 16: 'new mostrecent_notbefore'
            $mostrecent_notbefore = $ca_notbefore;
            $intca = $ca_id;
        }
    }

    if (! defined $intca) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_API_DETERMINE_ISSUING_CA_NO_MATCHING_CA",
            params  => {
                REQUESTED_NOTAFTER => $requested_notafter->iso8601(),
            },
        );
    }

    return $intca;
}

sub get_approval_message {
    my $self      = shift;
    my $arg_ref   = shift;
    my $sess_lang = CTX('session')->get_language();
    ##! 16: 'session language: ' . $sess_lang
    my $hash_sessionid = sha1_base64(CTX('session')->get_id());
    ##! 16: 'hash of the session ID: ' . $hash_sessionid

    my $result;

    # temporarily change the I18N language
    ##! 16: 'changing language to: ' . $arg_ref->{LANG}
    set_language($arg_ref->{LANG});            

    if (! defined $arg_ref->{TYPE}) {
        if ($arg_ref->{'WORKFLOW'} eq 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST') {
            $arg_ref->{TYPE} = 'CSR';
        }
        elsif ($arg_ref->{'WORKFLOW'} eq 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST') {
            $arg_ref->{TYPE} = 'CRR';
        }
    }
    if ($arg_ref->{TYPE} eq 'CSR') {
        ##! 16: 'CSR'
        my $wf_info = CTX('api')->get_workflow_info({
            WORKFLOW => $arg_ref->{WORKFLOW},
            ID       => $arg_ref->{ID},
        });
        # compute hash of CSR data (either PKCS10 or SPKAC)
        my $hash;
        my $spkac  = $wf_info->{WORKFLOW}->{CONTEXT}->{spkac};
        my $pkcs10 = $wf_info->{WORKFLOW}->{CONTEXT}->{pkcs10};
        if (! defined $spkac && ! defined $pkcs10) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_GET_APPROVAL_MESSAGE_NEITHER_SPKAC_NOR_PKCS10_PRESENT_IN_CONTEXT',
                log     => {
                    logger => CTX('log'),
                },
            );
        }
        elsif (defined $spkac) {
            $hash = sha1_base64($spkac);
        }
        elsif (defined $pkcs10) {
            $hash = sha1_base64($pkcs10);
        }
        # translate message
        $result = OpenXPKI::i18n::i18nGettext(
            'I18N_OPENXPKI_APPROVAL_MESSAGE_CSR',
            '__WFID__' => $arg_ref->{ID},
            '__HASH__' => $hash,
            '__HASHSESSIONID__' => $hash_sessionid,
        );
    }
    elsif ($arg_ref->{TYPE} eq 'CRR') {
        ##! 16: 'CRR'
        my $wf_info = CTX('api')->get_workflow_info({
            WORKFLOW => $arg_ref->{WORKFLOW},
            ID       => $arg_ref->{ID},
        });
        my $cert_id = $wf_info->{WORKFLOW}->{CONTEXT}->{cert_identifier};
        # translate message
        $result = OpenXPKI::i18n::i18nGettext(
            'I18N_OPENXPKI_APPROVAL_MESSAGE_CRR',
            '__WFID__' => $arg_ref->{ID},
            '__CERT_IDENTIFIER__' => $cert_id,
            '__HASHSESSIONID__' => $hash_sessionid,
        );
    }
    # change back the language to the original session language
    ##! 16: 'changing back language to: ' . $sess_lang
    set_language($sess_lang);

    ##! 16: 'result: ' . $result
    return $result;
}

# get current pki realm
sub get_pki_realm {
    return CTX('session')->get_pki_realm();
}

# get current user
sub get_user {
    return CTX('session')->get_user();
}

# get current user
sub get_role {
    return CTX('session')->get_role();
}

sub get_random {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;
    my $length  = $arg_ref->{LENGTH};
    ##! 4: 'length: ' . $length
    my $pki_realm = CTX('session')->get_pki_realm();

    my $default_token = CTX('pki_realm')->{$pki_realm}->{crypto}->{default};
    my $random = $default_token->command({
        COMMAND => 'create_random',
        RETURN_LENGTH => $length,
        RANDOM_LENGTH => $length,
    });
    ## DO NOT echo $random here, as it will possibly used as a password!
    return $random;
}

sub get_alg_names {
    my $self    = shift;
    my $pki_realm = CTX('session')->get_pki_realm();

    my $default_token = CTX('pki_realm')->{$pki_realm}->{crypto}->{default};
    my $alg_names = $default_token->command ({COMMAND => "list_algorithms", FORMAT => "alg_names"});
    return $alg_names;
}

sub get_param_names {
    my $self    = shift;
    my $arg_ref = shift;
    my $keytype = $arg_ref->{KEYTYPE};
    my $pki_realm = CTX('session')->get_pki_realm();

    my $default_token = CTX('pki_realm')->{$pki_realm}->{crypto}->{default};
    my $param_names = $default_token->command ({COMMAND => "list_algorithms",
                                                FORMAT  => "param_names",
                                                ALG     => $keytype});
    return $param_names;
}

sub get_param_values {
    my $self    = shift;
    my $arg_ref = shift;
    my $keytype = $arg_ref->{KEYTYPE};
    my $param_name = $arg_ref->{PARAMNAME};
    my $pki_realm = CTX('session')->get_pki_realm();

    my $default_token = CTX('pki_realm')->{$pki_realm}->{crypto}->{default};
    my $param_values = $default_token->command ({COMMAND => "list_algorithms",
                                                FORMAT  => "param_values",
                                                ALG     => $keytype,
                                                PARAM   => $param_name});
    return $param_values;
}

sub get_chain {
    my $self    = shift;
    my $arg_ref = shift;

    my $default_token;

    eval {
        my $pki_realm     = CTX('session')->get_pki_realm();
        $default_token = CTX('pki_realm')->{$pki_realm}->{crypto}->{default};
    };
    # ignore if this fails, as this is only needed within the
    # server if a user is connected. openxpkiadm -v -v uses this
    # method to show the chain (but not to convert the certificates)
    # we check later where the default token is needed whether it is
    # available

    my $return_ref;
    my @identifiers;
    my @certificates;
    my $finished = 0;
    my $complete = 0;
    my %already_seen; # hash of identifiers that have already been seen

    if (! defined $arg_ref->{START_IDENTIFIER}) {
	OpenXPKI::Exception->throw(
	    message => "I18N_OPENXPKI_SERVER_API_GET_CHAIN_START_IDENTIFIER_MISSING",
        );
    }
    my $start = $arg_ref->{START_IDENTIFIER};
    my $current_identifier = $start;
    my $dbi = CTX('dbi_backend');
    my @certs;

    while (! $finished) {
        ##! 128: '@identifiers: ' . Dumper(\@identifiers)
        ##! 128: '@certs: ' . Dumper(\@certs)
        push @identifiers, $current_identifier;
        my $cert = $dbi->first(
            TABLE   => 'CERTIFICATE',
            DYNAMIC => {
                IDENTIFIER => $current_identifier,
            },
        );
        if (! defined $cert) { #certificate not found
            $finished = 1;
        }
        else {
            if (defined $arg_ref->{OUTFORMAT}) {
                if ($arg_ref->{OUTFORMAT} eq 'PEM') {
                    push @certs, $cert->{DATA};
                }
                elsif ($arg_ref->{OUTFORMAT} eq 'DER') {
                    if (! defined $default_token) {
                        OpenXPKI::Exception->throw(
                            message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_GET_CHAIN_MISSING_DEFAULT_TOKEN',
                            log     => {
                                logger => CTX('log'),
                            },
                        );
                    }
                    push @certs, $default_token->command({
                        COMMAND => 'convert_cert',
                        DATA    => $cert->{DATA},
                        IN      => 'PEM',
                        OUT     => 'DER',
                    });
                }
            }
            if ($cert->{ISSUER_IDENTIFIER} eq $current_identifier) {
                # self-signed, this is the end of the chain
                $finished = 1;
                $complete = 1;
            }
            else { # go to parent
                $current_identifier = $cert->{ISSUER_IDENTIFIER};
                ##! 64: 'issuer: ' . $current_identifier
                if (defined $already_seen{$current_identifier}) {
                    # we've run into a loop!
                    $finished = 1;
                }
                $already_seen{$current_identifier} = 1;
            }
        }
    }
    $return_ref->{IDENTIFIERS} = \@identifiers;
    $return_ref->{COMPLETE}    = $complete;
    if (defined $arg_ref->{OUTFORMAT}) {
        $return_ref->{CERTIFICATES} = \@certs;
    }
    return $return_ref;
}

# get one or more CA certificates
# FIXME: this still assumes we have files in the config
sub get_ca_certificate {
    my %response;

    ##! 2: "get pki realm configuration"
    my $realms = CTX('pki_realm');
    if (!(defined $realms && (ref $realms eq 'HASH'))) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_GET_CA_CERTIFICATES_PKI_REALM_CONFIGURATION_UNAVAILABLE"
        );
    }

    ##! 2: "get session's realm"
    my $thisrealm = CTX('session')->get_pki_realm();
    ##! 2: "$thisrealm"
    if (! defined $thisrealm) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_GET_CA_CERTIFICATES_PKI_REALM_NOT_SET"
	);
    }

    if (exists $realms->{$thisrealm}->{ca}) {
	# if no ca certificates could be found this key will not exist
        ##! 4: "ca cert exists"
	foreach my $caid (keys %{$realms->{$thisrealm}->{ca}->{id}}) {
            my $notbefore = $realms->{$thisrealm}->{ca}->{id}->{$caid}->{notbefore};
            my $notafter  = $realms->{$thisrealm}->{ca}->{id}->{$caid}->{notafter};
	    $response{$caid} = 
	    {
		notbefore => OpenXPKI::DateTime::convert_date(
		    {
			DATE => $notbefore,
			OUTFORMAT => 'printable',
		    }),
		notafter => OpenXPKI::DateTime::convert_date(
		    {
			DATE => $notafter,
			OUTFORMAT => 'printable',
		    }),
		cacert => $realms->{$thisrealm}->{ca}->{id}->{$caid}->{crypto}->get_certfile(),

	    };
	}
    }
    ##! 64: "response: " . Dumper(%response)
    return \%response;
}

sub list_ca_ids {
    my $self    = shift;
    my $arg_ref = shift;
    my $cfg_id  = $arg_ref->{CONFIG_ID};
    ##! 16: 'cfg_id: ' . $cfg_id

    my %response;

    ##! 2: "get pki realm configuration"
    my $realms = CTX('pki_realm_by_cfg')->{$cfg_id}; 
    if (! defined $cfg_id) {
        $realms = CTX('pki_realm');
    }
    if (!(defined $realms && (ref $realms eq 'HASH'))) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_LIST_CA_IDS_PKI_REALM_CONFIGURATION_UNAVAILABLE"
        );
    }

    ##! 2: "get session's realm"
    my $thisrealm = CTX('session')->get_pki_realm();
    ##! 2: "$thisrealm"
    if (! defined $thisrealm) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_LIST_CA_IDS_PKI_REALM_NOT_SET"
	);
    }
    
    ##! 32: Dumper($realms->{$thisrealm}->{ca})
    if (exists $realms->{$thisrealm}->{ca}) {
        ##! 64: 'if!'
        my @return = sort keys %{$realms->{$thisrealm}->{ca}->{id}};
        ##! 64: Dumper(\@return)
	return \@return;
    }
    
    return;
}

sub __get_profile_index {
    my $self    = shift;
    my $arg_ref = shift;
    my $profile = $arg_ref->{PROFILE};
    my $cfg_id  = $arg_ref->{CONFIG_ID};

    ##! 1: 'start'
    my $pki_index = $self->get_pki_realm_index({
        CONFIG_ID => $cfg_id,
    });
    
    my $count = CTX('xml_config')->get_xpath_count(
        XPATH     => [ 'pki_realm', 'common', 'profiles', 'endentity', 'profile' ],
        COUNTER   => [ $pki_index , 0       , 0         , 0 ],
        CONFIG_ID => $cfg_id,
    );
    ##! 16: 'count: ' . $count
    my $profile_index;
  PROFILE_INDEX:
    for (my $i = 0; $i < $count; $i++) {
        my $profile_id = CTX('xml_config')->get_xpath(
            XPATH     => [ 'pki_realm', 'common', 'profiles', 'endentity', 'profile', 'id' ],
            COUNTER   => [ $pki_index , 0       , 0         , 0          , $i       , 0    ],
            CONFIG_ID => $cfg_id,
        ); 
        ##! 64: 'profile_id: ' . $profile_id
        if ($profile_id eq $profile) {
            ##! 64: 'found ...'
            $profile_index = $i;
            last PROFILE_INDEX;
        }
    }
    if (! defined $profile_index) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_GET_PROFILE_INDEX_PROFILE_NOT_FOUND',
            params  => {
                PROFILE => $profile,
            },
        );
    }
    ##! 1: 'end'
    return $profile_index;
}

sub get_pki_realm_index {
    my $self    = shift;
    my $arg_ref = shift;
    my $pki_realm = CTX('session')->get_pki_realm();

    ## scan for correct pki realm
    my $index = CTX('xml_config')->get_xpath_count(
        XPATH     => "pki_realm",
        CONFIG_ID => $arg_ref->{CONFIG_ID},
    );
    for (my $i=0; $i < $index; $i++)
    {
        if (CTX('xml_config')->get_xpath (XPATH   => ["pki_realm", "name"],
                                          COUNTER => [$i, 0],
                                          CONFIG_ID => $arg_ref->{CONFIG_ID},)
            eq $pki_realm)
        {
            $index = $i;
        } else {
            if ($index == $i+1)
            {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_SERVER_API_GET_PKI_REALM_INDEX_FAILED");
            }
        }
    }

    return $index;
}

sub get_roles {
    return [ CTX('acl')->get_roles() ];
}

sub get_available_cert_roles {
    my $self      = shift;
    my $arg_ref   = shift;
    my $cfg_id    = $arg_ref->{CONFIG_ID};
    if (! defined $cfg_id) {
        $cfg_id = $self->get_current_config_id();
    }
    my %available_roles = ();

    ##! 1: 'start'

    my $pki_realm = CTX('session')->get_pki_realm();
    my @profiles  = ();
    my $index     = $self->get_pki_realm_index({
        CONFIG_ID => $cfg_id,
    });

    my $count = CTX('xml_config')->get_xpath_count(
     XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile"],
     COUNTER => [$index     , 0       , 0         , 0],
     CONFIG_ID => $cfg_id,
    );
    ##! 16: 'count: ' . $count
    for (my $i=0; $i < $count; $i++) {
        my $id = CTX('xml_config')->get_xpath(
            XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "id"],
            COUNTER => [$index     , 0       , 0         , 0          , $i       , 0   ],
            CONFIG_ID => $cfg_id,
        );
        next if ($id eq "default");
        my $role_count = 0;
        eval {
            $role_count = CTX('xml_config')->get_xpath_count(
                XPATH   => ['pki_realm', 'common', 'profiles', 'endentity', 'profile', 'role'],
                COUNTER => [$index     , 0       , 0         , 0          , $i ],
                CONFIG_ID => $cfg_id,
            );
        };
        ##! 16: 'role_count: ' . $role_count
        foreach (my $ii = 0; $ii < $role_count; $ii++) {
            my $role = CTX('xml_config')->get_xpath(
                XPATH   => ['pki_realm', 'common', 'profiles', 'endentity', 'profile', 'role'],
                COUNTER => [$index     , 0       , 0         , 0          , $i       , $ii   ],
                CONFIG_ID => $cfg_id,
            );
            ##! 16: 'role: ' . $role
            $available_roles{$role} = 1;
        }
    }
    ##! 1: 'end'
    my @roles = keys %available_roles;
    return \@roles;
}

sub get_cert_profiles {
    my $index = get_pki_realm_index();

    ## get all available profiles
    my %profiles = ();
    my $count = CTX('xml_config')->get_xpath_count (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile"],
                    COUNTER => [$index, 0, 0, 0]);
    for (my $i=0; $i <$count; $i++)
    {
        my $id = CTX('xml_config')->get_xpath (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "id"],
                    COUNTER => [$index, 0, 0, 0, $i, 0]);
        next if ($id eq "default");
        $profiles{$id} = $i;
    }

    return \%profiles;
}

sub get_cert_subject_profiles {
    my $self = shift;
    my $args = shift;

    my $index   = get_pki_realm_index();
    my $profile = $args->{PROFILE};

    ## get index of profile
    my $profiles = get_cert_profiles();
       $profile  = $profiles->{$profile};

    ## get all available profiles
    my %profiles = ();
    my $count = CTX('xml_config')->get_xpath_count (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "subject"],
                    COUNTER => [$index, 0, 0, 0, $profile]);
    for (my $i=0; $i <$count; $i++)
    {
        my $id = CTX('xml_config')->get_xpath (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "subject", "id"],
                    COUNTER => [$index, 0, 0, 0, $profile, $i, 0]);
        my $label = CTX('xml_config')->get_xpath (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "subject", "label"],
                    COUNTER => [$index, 0, 0, 0, $profile, $i, 0]);
        my $desc = CTX('xml_config')->get_xpath (
                    XPATH   => ["pki_realm", "common", "profiles", "endentity", "profile", "subject", "description"],
                    COUNTER => [$index, 0, 0, 0, $profile, $i, 0]);
        $profiles{$id}->{LABEL}       = $label;
        $profiles{$id}->{DESCRIPTION} = $desc;
    }

    return \%profiles;
}


sub get_export_destinations
{
    ##! 1: "finished"
    my $self = shift;
    my $args = shift;
    my $pki_realm = CTX('session')->get_pki_realm();

    ##! 2: "load destination numbers"
    my $export = CTX('xml_config')->get_xpath (
                     XPATH   => [ 'common/data_exchange/export/dir' ],
                     COUNTER => [ 0 ]);
    my $import = CTX('xml_config')->get_xpath (
                     XPATH   => [ 'common/data_exchange/import/dir' ],
                     COUNTER => [ 0 ]);
    my @list = ();
    foreach my $dir ($import, $export)
    {
        opendir DIR, $dir;
        my @filenames = grep /^[0-9]+/, readdir DIR;
        close DIR;
        foreach my $filename (@filenames)
        {
            next if (not length $filename);
            $filename =~ s/^([0-9]+)(|[^0-9].*)$/$1/;
            push @list, $filename if (length $filename);
        }
    }

    ##! 2: "load all servers"
    my %servers = %{ $self->get_servers()->{$pki_realm} };

    ##! 2: "build hash with numbers and names of affected servers"
    my %result = ();
    my $last   = -1;
    foreach my $item (sort @list)
    {
        next if ($last == $item);
        $result{$item} = $servers{$item};
        $last = $item;
    }

    ##! 1: "finished"
    return \%result;
}

sub get_servers {
    return CTX('acl')->get_servers();
}

sub convert_csr {
    my $self    = shift;
    my $arg_ref = shift;

    my $realm   = CTX('session')->get_pki_realm();
    my $default_token = CTX('pki_realm')->{$realm}->{crypto}->{default};
    my $data = $default_token->command({
        COMMAND => 'convert_pkcs10',
        IN      => $arg_ref->{IN},
        OUT     => $arg_ref->{OUT},
        DATA    => $arg_ref->{DATA},
    });
    return $data;
}

sub convert_certificate {
    my $self    = shift;
    my $arg_ref = shift;

    my $realm   = CTX('session')->get_pki_realm();
    my $default_token = CTX('pki_realm')->{$realm}->{crypto}->{default};
    my $data = $default_token->command({
        COMMAND => 'convert_cert',
        IN      => $arg_ref->{IN},
        OUT     => $arg_ref->{OUT},
        DATA    => $arg_ref->{DATA},
    });
    return $data;
}

sub create_bulk_request_ticket {
    ##! 1: 'start'
    my $self      = shift;
    my $arg_ref   = shift;
    my $workflows = $arg_ref->{WORKFLOWS};
    my $ser       = OpenXPKI::Serialization::Simple->new();

    my $dummy_workflow = Workflow->new();
    ##! 16: 'dummy_workflow: ' . Dumper $dummy_workflow
    $dummy_workflow->context->param('creator' => CTX('session')->get_user());

    ##! 16: 'dummy_workflow: ' . Dumper $dummy_workflow
    my $ticket = CTX('notification')->notify({
        MESSAGE  => 'create_bulk_request',
        WORKFLOW => $dummy_workflow,
    });
    $dummy_workflow->context->param('ticket' => $ser->serialize($ticket));
    $dummy_workflow->context->param('workflows' => $ser->serialize($workflows));

    CTX('notification')->notify({
        MESSAGE  => 'create_bulk_request_workflows',
        WORKFLOW => $dummy_workflow,
    });

    return $ticket;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::API::Default

=head1 Description

This module contains the API functions which do not fall into one
of the other categories (i.e. Session, Visualization, Workflow, ...).
They were once the toplevel OpenXPKI::Server::API methods, but the
structure is now different.

=head1 Functions

=head2 get_approval_message

Gets the approval message that is to be signed for a signature-based
approval. Takes the parameters TYPE (can either be CSR or CRR),
WORKFLOW, ID (specifies the workflow from which the data is taken)
and optionally LANG (which specifies the language that is used to
translate the message).

=head2 get_user

Get session user.

=head2 get_role

Get session user's role.

=head2 get_pki_realm

Get PKI realm for this session.

=head2 get_ca_ids

Returns a list of all issuing CA IDs that are available.
Return structure:
  CA_ID => array ref of CA IDs

=head2 get_ca_certificate

Returns CA certificate details.
Expects named parameter 'CA_ID' which can be either a scalar or an 
array ref indicating which CA certificates to fetch.
If named paramter 'OUTFORM' is specified, it must be one of 'PEM' or
'DER'. In this case the returned structure will return the CA certificate
in the specified format.

Returns an array ref containing the CA certificate information in the
order that was requested.

Return structure:
  CACERT => [
    {
        CA_ID => CA ID (as requested)
        NOTBEFORE => certifiate notbefore (ISO8601)
        NOTAFTER => certifiate notafter  (ISO8601)
        CERTIFICATE => certificate data (only if OUTFORM was specified)
    }

  ]

=head2 get_chain

Returns the certificate chain starting at a specified certificate.
Expects a hash ref with the named parameter START_IDENTIFIER (the
identifier from which to compute the chain) and optionally a parameter
OUTFORMAT, which can be either 'PEM' or 'DER'.
Returns a hash ref with the following entries:

    IDENTIFIERS   the chain of certificate identifiers as an array
    CERTIFICATES  the certificates as an array of data in outformat
                  (if requested)
    COMPLETE      1 if the complete chain was found in the database
                  0 otherwise

=head2 get_possible_profiles_for_role

Returns an array reference of possible certificate profiles for a given
certificate role (passed in the named parameter ROLE) taken from the
configuration.

=head2 get_cert_subject_styles

Returns the configured subject styles for the specified profile.

Parameters:

  PROFILE     name of the profile to query
  CONFIG_ID   configuration ID
  PKCS10      certificate request to parse (optional)

Returns a hash ref with the following structure:


=head2 get_additional_information_fields

Returns a hash ref containing all additional information fields that are
configured.

Return structure: hash ref; key is the name of the field, value is the
corresponding I18N tag.
