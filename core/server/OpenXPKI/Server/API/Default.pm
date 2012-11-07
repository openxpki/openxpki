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
            'context1.WORKFLOW_CONTEXT_KEY'   => {VALUE => 'workflow_parent_id'},
            'context2.WORKFLOW_CONTEXT_KEY'   => {VALUE => 'creator'},
            'context3.WORKFLOW_CONTEXT_KEY'   => {VALUE => 'cert_identifier'},
            'context2.WORKFLOW_CONTEXT_VALUE' => {VALUE => $user},
            'CERTIFICATE.PKI_REALM'           => {VALUE => $realm},
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
    my $default_token = CTX('api')->get_default_token();
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

sub get_head_version_id {
    my $self = shift;
    return CTX('config')->get_head_version();
}

sub get_current_config_id {
    my $self = shift;
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_GET_CURRENT_CONFIG_ID',
    );   
}

sub list_config_ids {
    my $self = shift;
    ##! 1: 'start'
    my $config_entries = CTX('dbi_backend')->select(
        TABLE   => 'CONFIG',
        DYNAMIC => {
            CONFIG_IDENTIFIER => {VALUE => '%', OPERATOR => "LIKE"},
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

sub __fetch_input_element_definitions {
    
    my $self = shift;   
    my $profile = shift;
    my $input_names = shift;  
    my $csr_info = shift;
    
    my $config = CTX('config');
    
    my @definitions;
            
    foreach my $input_name (@{$input_names}) {
        my ($input, $input_path); 
        ##! 32: "Input $input_name"
        # each input name can have a local or/and a global definiton, 
        # we need to probe where to find it 
        foreach my $path ("profile.$profile.template.$input_name", "profile.template.$input_name") {                            
            $input = $config->get_hash($path);            
            if ($input) {
                ##! 64: "Element found at $path"
                $input_path = $path;
                last;                        
            }
        }
        
        if (!$input) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_API_DEFAULT_NO_SUCH_INPUT_ELEMENT_DEFINED",
                param => {
                    'input' => $input_name,
                    'profile' => $profile,
                }
            );
        }

        # Uppercase the keys and push it to the array
        my %ucinput = map { uc $_ => $input->{$_} } keys %{$input};
        if (defined $csr_info) {

            my $source = $input->{'source'};
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
                    $ucinput{DEFAULT} = $match;
                }
            }
        }
 
        # if type is select, add options array ref
        if ($ucinput{TYPE} eq 'select') {
            ##! 32: 'type is select'
            my @options = $config->get_list("$input_path.option");
            $ucinput{OPTIONS} = \@options;                  
        }
        
        # SAN use fields with dynamic key/value assignment 
        # We introduce a new type "dynamic" for that
        if ($ucinput{TYPE} eq 'keyvalue') {            
            # "key" and "value" are a hash            
            foreach my $key (qw(key value)) {
                my %hash = %{$config->get_hash("$input_path.$key")};
                %hash = map { uc $_ => $hash{$_} } keys %hash;                     
                # To make it worse, they can have options which is a list of hash
                if ($hash{TYPE} eq 'select') {
                    my @options;                    
                    for (my $i=0; $i<$config->get_size("$input_path.$key.option"); $i++) {
                       my %sub = %{$config->get_hash("$input_path.$key.option.$i")};
                       %sub = map { uc $_ => $sub{$_} } keys %sub;
                       push @options, \%sub;  
                    }                    
                    $hash{OPTIONS} = \@options; 
                }                
                $ucinput{uc($key)} = \%hash;
            }
        }
        push @definitions, \%ucinput; 
    }
    ##! 64: 'Definitions: ' . Dumper @definitions
    return \@definitions;    
}


sub get_cert_subject_styles {
    my $self      = shift;
    my $arg_ref   = shift;
    my $profile   = $arg_ref->{PROFILE};
    my $cfg_id    = $arg_ref->{CONFIG_ID};
    my $pkcs10    = $arg_ref->{PKCS10};
    ##! 1: 'start'

    my $config = CTX('config');
    
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

    my $styles = {};
 
    my @style_names = $config->get_keys("profile.$profile.style");
 
    ##! 16: 'styles: ' . Dumper @style_names
    # iterate over all subject styles
    foreach my $id (@style_names) {

        ##! 64: 'style id: ' . $id        
        my $style_config = $config->get_wrapper("profile.$profile.style.$id");
        
        # verbose texts
        foreach my $key (qw(label description)) {
            ##! 32: "Key: $key, Value: " . $style_config->get($key)
            $styles->{$id}->{uc($key)} = $style_config->get($key);     
        }

        # subject toolkit template
        $styles->{$id}->{DN} = $style_config->get('subject'); 

        # FIX ME Bulk Flag
        ##! 16: 'bulk defined for this style'
        $styles->{$id}->{BULK} = $style_config->get('bulk');
        

        # The names of the fields are a list at ui.subject
        my @input_names = $style_config->get_list('ui.subject');        
        
        # The helper probes for the field definitions 
        # and loads them into a suitable hash structure 
        $styles->{$id}->{TEMPLATE}->{INPUT} = 
                $self->__fetch_input_element_definitions( $profile, \@input_names, $csr_info);            
            
        
        # Do the same for the additional info parts
        @input_names = $style_config->get_list('ui.info');        

        $styles->{$id}->{ADDITIONAL_INFORMATION}->{INPUT} = 
            $self->__fetch_input_element_definitions( $profile, \@input_names, $csr_info );            
        
        # And again for SANs
        @input_names = $style_config->get_list('ui.san');        
        
        $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES} = 
            $self->__fetch_input_element_definitions( $profile, \@input_names ); # no csr_info for san            
        
    }
    ##! 128: 'styles: ' . Dumper $styles
    return $styles;
}

sub get_additional_information_fields {
    my $self      = shift;
    my $arg_ref   = shift;

    ##! 1: 'start'
    my $config = CTX('config');    
    my @profiles = $config->get_keys('profile');

    ##! 32: 'Found profiles : ' . Dumper @profiles
       
    my $additional_information = {};
        
    # iterate through all profile and summarize all additional information
    # fields (may be redundant and even contradicting, but we only collect
    # the 'union' of these here; first one wins...)
    foreach my $profile (@profiles) {
    	##! 16: 'profile  ' . $profile
        my @fields;
        foreach my $style ($config->get_keys("profile.$profile.style")) {
            push @fields, $config->get_list("profile.$profile.style.$style.ui.info");
        }
        
        ##! 32: 'Found fields: ' . join ", ", @fields
        
        foreach my $field (@fields) {
            
            # We need only one hit per field
            next if $additional_information->{ALL}->{$field};
                          
            # Resolve labels for fields            
            foreach my $path ("profile.$profile.template.$field", "profile.template.$field") {                            
                if (my $label = $config->get("$path.label")) {
                    ##! 16: "additional information: $field (label: $label)"            
                    $additional_information->{ALL}->{$field} = $label;
                    last;
                }
            }
        }        	    
	}
    return $additional_information;
}    

sub get_possible_profiles_for_role {
    my $self      = shift;
    my $arg_ref   = shift;
    my $req_role  = $arg_ref->{ROLE};
     
    ##! 1: 'start'
    ##! 16: 'Requested role ' . $req_role

    my $config = CTX('config');    
    my @profiles = $config->get_keys('profile');
    my @matching_profiles; 
    
    foreach my $profile (@profiles) {
        my @roles = $config->get_list("profile.$profile.role");
        ##! 16: "Profile $profile, Roles " .join " ", @roles              
        if (grep /^$req_role$/,  @roles) {
            ##! 16: 'Profile matches role' 
            push @matching_profiles, $profile;     
        }
    }
    
    ##! 1: 'end'
    return \@matching_profiles;
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

    my $default_token = CTX('api')->get_default_token();
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

    my $default_token = CTX('api')->get_default_token();
    my $alg_names = $default_token->command ({COMMAND => "list_algorithms", FORMAT => "alg_names"});
    return $alg_names;
}

sub get_param_names {
    my $self    = shift;
    my $arg_ref = shift;
    my $keytype = $arg_ref->{KEYTYPE};

    my $default_token = CTX('api')->get_default_token();
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

    my $default_token = CTX('api')->get_default_token();
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
        $default_token = CTX('api')->get_default_token();
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
                IDENTIFIER => {VALUE => $current_identifier},
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
                    
                    #FIXME - this is stupid but at least on perl 5.10 it helps with the "double utf8 encoded downloads"                    
                    my $utf8fix = $default_token->command({
                        COMMAND => 'convert_cert',
                        DATA    => $cert->{DATA},
                        IN      => 'PEM',
                        OUT     => 'DER',
                    });
                    Encode::_utf8_on($utf8fix );
                    push @certs, $utf8fix ;
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

    ##! 1: 'start'
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_METHOD_OBSOLETE',
        params  => {
            METHOD => '__get_profile_index',
        },
    );    
}

sub get_pki_realm_index {
     ##! 1: 'start'
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_METHOD_OBSOLETE',
        params  => {
            METHOD => 'get_pki_realm_index',
        },
    );    
}

sub get_roles {    
    #FIXME-ACL - should go with the new acl system
    return CTX('config')->get_keys('auth.roles');
}

sub get_available_cert_roles {
    my $self      = shift;
    my $arg_ref   = shift;

    my %available_roles = ();

    ##! 1: 'start'
    my $config = CTX('config');
    my @profiles; 
    if ($arg_ref->{PROFILES}) {
        @profiles = @{$arg_ref->{PROFILES}};
    } else {
        @profiles = $config->get_keys('profile');    
    }
    
    ##! 16: 'Profiles ' .join " ", @profiles     
    foreach my $profile (@profiles) {
        my @roles = $config->get_list("profile.$profile.role");
        ##! 16: 'Roles ' .join " ", @roles
        map { $available_roles{$_} = 1 if ($_); } @roles;
    }
 
    ##! 1: 'end'    
    my @roles = keys %available_roles;
    return \@roles;
}

sub get_cert_profiles {
    
    my $config = CTX('config');    

    my %profiles = map { $_ => 1 } $config->get_keys('profile');
    
    delete $profiles{'template'};

    ##! 16: 'Profiles ' .Dumper %profiles
    
    return \%profiles;
}
 
sub get_cert_subject_profiles {
    my $self = shift;
    my $args = shift;
    my $profile = $args->{PROFILE};

    ##! 1: 'Start '

    my $config = CTX('config');    

    my @style_names = $config->get_keys("profile.$profile.style");

    ## get all available profiles
    my %styles = ();
    foreach my $style (@style_names) {        
        $styles{$style}->{LABEL}       = $config->get("profile.$profile.style.$style.label");
        $styles{$style}->{DESCRIPTION} = $config->get("profile.$profile.style.$style.description");
    }

    ##! 32: Dumper %profiles 
    return \%styles;
}

# FIXME - needs migration
sub get_export_destinations
{
    ##! 1: "finished"
    my $self = shift;
    my $args = shift;
    my $pki_realm = CTX('session')->get_pki_realm();

    ##! 2: "load destination numbers"
    my $export = CTX('config')->get('system.server.data_exchange.export'); 
    my $import = CTX('config')->get('system.server.data_exchange.import');
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

# FIXME - needs migration
sub get_servers {
    return {};
}

sub convert_csr {
    my $self    = shift;
    my $arg_ref = shift;

    my $default_token = CTX('api')->get_default_token();
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
    
    my $default_token = CTX('api')->get_default_token();
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
  PKCS10      certificate request to parse (optional)

Returns a hash ref with the following structure:
FIXME

=head2 get_additional_information_fields

Returns a hash ref containing all additional information fields that are
configured.

Return structure: hash ref; key is the name of the field, value is the
corresponding I18N tag.


=head2 get_available_cert_roles

Parameters:

  PROFILES  arrayref of profiles to query

Scan through profiles and find all roles inside them.
If PROFILES is given, scan only through those profiles. 
Return the role names as arrarref. 

=head2 get_cert_profiles

Return a hash ref with all profiles. The key is the id of the profile, the 
value was formerly set as the position in the xml tree, not it is simply "1".


=head2 get_cert_subject_profiles

Returns a hash with label and description of all subject styles for a 
given profile. FIXME: The name is misleading. 