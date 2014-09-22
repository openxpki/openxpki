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
use Digest::SHA qw( sha1_base64 );
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
            'context2.WORKFLOW_CONTEXT_KEY'   => {VALUE => 'creator'},
            'context3.WORKFLOW_CONTEXT_KEY'   => {VALUE => 'cert_identifier'},
            'context2.WORKFLOW_CONTEXT_VALUE' => {VALUE => $user},
            'CERTIFICATE.PKI_REALM'           => {VALUE => $realm},
        },
        JOIN => [
            [
                undef,
                'WORKFLOW_CONTEXT_VALUE',
                'IDENTIFIER',
            ],
            [
                'WORKFLOW_SERIAL',
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
    my $cert_identifier = $arg_ref->{'IDENTIFIER'};

    # Fallback for legacy calls with csr instead of identifier
    if (!$cert_identifier && $csr_serial) {
        my $cert_identifier_result = CTX('dbi_backend')->first(
            TABLE   => 'CERTIFICATE',
            DYNAMIC => {
                CSR_SERIAL => $csr_serial,
            },
        );
        $cert_identifier = $cert_identifier_result->{IDENTIFIER};
    }

    my @result;
    # CSR Workflow
    my $workflow_id_result = CTX('dbi_backend')->first(
        TABLE   => 'CERTIFICATE_ATTRIBUTES',
        DYNAMIC => {
            'IDENTIFIER' => $cert_identifier,
            ATTRIBUTE_KEY => 'system_csr_workflow',
        },
    );
    my $workflow_id = $workflow_id_result->{ATTRIBUTE_VALUE};
    # we fake the old return structure to satisfy the mason ui
    # # FIXME - needs remodeling
    push @result, {
        'WORKFLOW.WORKFLOW_SERIAL' => $workflow_id,
        'WORKFLOW.WORKFLOW_TYPE' => CTX('api')->get_workflow_type_for_id({ ID => $workflow_id })
    } if ($workflow_id);


    # CRR Workflow
    $workflow_id_result = CTX('dbi_backend')->select(
        TABLE   => 'CERTIFICATE_ATTRIBUTES',
        DYNAMIC => {
            'IDENTIFIER' => $cert_identifier,
            ATTRIBUTE_KEY => 'system_crr_workflow',
        },
    );
    foreach my $line (@{$workflow_id_result}) {
        $workflow_id = $line->{ATTRIBUTE_VALUE};
        push @result, {
            'WORKFLOW.WORKFLOW_SERIAL' => $workflow_id,
            'WORKFLOW.WORKFLOW_TYPE' => CTX('api')->get_workflow_type_for_id({ ID => $workflow_id })
        } if ($workflow_id);
    }
    return \@result;

}

sub get_head_version_id {
    my $self = shift;
    return CTX('config')->get_head_version();
}

sub get_approval_message {
    my $self      = shift;
    my $arg_ref   = shift;
    my $sess_lang = CTX('session')->get_language();
    ##! 16: 'session language: ' . $sess_lang

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
            '__CERT_SUBJECT__' => $wf_info->{WORKFLOW}->{CONTEXT}->{cert_subject}
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
            'I18N_OPENXPKI_APPROVAL_MESSAGE_CRR'
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

sub get_session_info {

    my $self    = shift;

    my $session = CTX('session');
    return {
        name => $session->get_user(),
        role => $session->get_role(),
        role_label => CTX('config')->get([ 'auth', 'roles', $session->get_role(), 'label' ]),
        pki_realm => $session->get_pki_realm(),
        pki_realm_label => CTX('config')->get([ 'system', 'realms', $session->get_pki_realm(), 'label' ]),
        lang => 'en',
        version => CTX('config')->get_version(),
    }

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

    my $inner_format = $arg_ref->{OUTFORMAT} || '';
    if ($arg_ref->{BUNDLE}) {
        $inner_format = 'PEM';
    }



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
            if ($inner_format) {
                if ($inner_format eq 'PEM') {
                    push @certs, $cert->{DATA};
                }
                elsif ($inner_format eq 'DER') {
                    if (! defined $default_token) {
                        OpenXPKI::Exception->throw(
                            message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_GET_CHAIN_MISSING_DEFAULT_TOKEN',
                            log     => {
                                logger => CTX('log'),
                            },
                        );
                    }

                    my $utf8fix = $default_token->command({
                        COMMAND => 'convert_cert',
                        DATA    => $cert->{DATA},
                        IN      => 'PEM',
                        OUT     => 'DER',
                    });
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

    # Return a pkcs7 structure instead of the hash
    if ($arg_ref->{BUNDLE}) {

        # we do NOT include the root in p7 bundles
        pop @certs if ($complete && !$arg_ref->{KEEPROOT});

        my $result = $default_token->command({
            COMMAND          => 'convert_cert',
            DATA             => \@certs,
            OUT              =>  ($arg_ref->{OUTFORMAT} eq 'DER' ? 'DER' : 'PEM'),
            CONTAINER_FORMAT => 'PKCS7',
        });
        return $result;
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

    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_METHOD_OBSOLETE',
        params  => {
            METHOD => 'list_ca_ids ',
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

sub send_notification {
    ##! 1: 'start'
    my $self      = shift;
    my $arg_ref   = shift;

    my $message = $arg_ref->{MESSAGE};
    my $vars = $arg_ref->{PARAMS};

    return CTX('notification')->notify({
        MESSAGE => $message,
        DATA => $vars
    });

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

By setting "BUNDLE => 1" you will not get a hash but a PKCS7 encoded bundle
holding the requested certificate and all intermediates (if found). Add
"KEEPROOT => 1" to also have the root in PKCS7 container.

