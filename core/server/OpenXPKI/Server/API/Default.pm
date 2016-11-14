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
    my @subject;
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
            push @subject, $cert->{SUBJECT};
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
                } elsif ($inner_format eq 'HASH') {
                    # unset DATA to save some bytes
                    delete $cert->{DATA};
                    push @certs, $cert;
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

    $return_ref->{SUBJECT} = \@subject;
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

=head2 import_certificate( { DATA, PKI_REALM, FORCE_NOCHAIN, FORCE_ISSUER, REVOKED })

=cut

sub import_certificate {
    my $self    = shift;
    my $arg_ref = shift;

    my $default_token = CTX('api')->get_default_token();
    my $dbi = CTX('dbi_backend');

    my $realm = $arg_ref->{PKI_REALM};
    my $do_update = $arg_ref->{UPDATE};

    my $cert = OpenXPKI::Crypto::X509->new(
        TOKEN => $default_token,
        DATA  => $arg_ref->{DATA},
    );
    my $cert_identifier = $cert->get_identifier();

    # Check if the certificate is already in the PKI
    my $db_hash = $dbi->first(
        TABLE   => 'CERTIFICATE',
        DYNAMIC => { IDENTIFIER => $cert_identifier }
    );

    if ($db_hash) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_CERTIFICATE_ALREADY_EXISTS',
            params  => {
                IDENTIFIER => $db_hash->{IDENTIFIER},
                PKI_REALM => $db_hash->{PKI_REALM} || '',
                STATUS => $db_hash->{STATUS},
            },
        ) if (!$do_update);
    } else {
        $do_update = 0;
    }

    $db_hash = { $cert->to_db_hash() };
    $db_hash->{STATUS} = ($arg_ref->{REVOKED} ? 'REVOKED' : 'ISSUED');
    $db_hash->{PKI_REALM} = $arg_ref->{PKI_REALM} if ($arg_ref->{PKI_REALM});

    my $self_signed = 1;
    my $issuer_query;
    # Check if self-signed based on Key Ids, if set
    if (defined $cert->get_subject_key_id()
        && defined $cert->get_authority_key_id()) {

        if ($cert->get_subject_key_id() ne $cert->get_authority_key_id()) {
            $self_signed = 0;
            $issuer_query = { SUBJECT_KEY_IDENTIFIER => $cert->get_authority_key_id() };
        }

    # certificates without AIK/SK set
    } else {
        if ($cert->{PARSED}->{BODY}->{SUBJECT} ne $cert->{PARSED}->{BODY}->{ISSUER}) {
            $self_signed = 0;
            $issuer_query = { SUBJECT => $cert->{PARSED}->{BODY}->{ISSUER} };
        }
    }

    # Lookup issuer if not self-signed
    my $issuer_identifier;
    if ($self_signed) {
        $db_hash->{ISSUER_IDENTIFIER} = $cert_identifier;
    } else {

        # Explicit issuer wins over issuer query
        if ($arg_ref->{ISSUER}) {

            if ($arg_ref->{FORCE_NOCHAIN}) {
                OpenXPKI::Exception->throw(
                    message => 'Option force-no-chain is not allowed with explicit issuer, use force-issuer instead!'
                ) ;
            }
            $issuer_query = { IDENTIFIER => $arg_ref->{ISSUER} };
        }

        # TODO - check for non-uniq subjects
        my $db_result = $dbi->select(
            TABLE   => 'CERTIFICATE',
            DYNAMIC => $issuer_query,
        );

        if ((scalar @{$db_result}) > 1) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_ISSUER_QUERY_AMBIGIOUS_RESULT',
                params  => {
                    RESULTS => scalar @{$db_result},
                    QUERY => Dumper $issuer_query,
                },
            )
        }

        if ((scalar @{$db_result}) == 1) {

            my $issuer_cert = $db_result->[0];

            my $valid;
            
            # No verfiy requested ?
            if($arg_ref->{FORCE_NOVERIFY})  {
                $valid = 1;
                CTX('log')->log(
                    MESSAGE  => "Importing certificate without chain verification! $cert_identifier / " . $cert->get_subject(),
                    PRIORITY => 'warn',
                    FACILITY => ['audit','system']
                );
              
            # check if the issuer is already a root
            } elsif ($issuer_cert->{IDENTIFIER} eq $issuer_cert->{ISSUER_IDENTIFIER}) {
                $valid = $default_token->command({
                    COMMAND => 'verify_cert',
                    CERTIFICATE => $cert->{DATA},
                    TRUSTED => $issuer_cert->{DATA},
                });

            } else {
                # get the chain starting from the issuer

                #validate_certificate
                my $chain = $self->get_chain({ START_IDENTIFIER => $issuer_cert->{IDENTIFIER}, OUTFORMAT => 'PEM' });
                # we can only verify with a complete chain
                if ($chain->{COMPLETE}) {
                    my @work_chain = @{$chain->{CERTIFICATES}};
                    my $root = pop @work_chain;

                    $valid = $default_token->command({
                        COMMAND => 'verify_cert',
                        CERTIFICATE => $cert->{DATA},
                        TRUSTED => $root,
                        CHAIN => join "\n", @work_chain
                    });
                } elsif($arg_ref->{FORCE_NOCHAIN}) {
                    # Accept an incomplete chain
                    $valid = 1;
                    CTX('log')->log(
                        MESSAGE  => "Importing certificate with incomplete chain! $cert_identifier / " . $cert->get_subject(),
                        PRIORITY => 'warn',
                        FACILITY => ['audit','system']
                    );
                }
            }

            if (!$valid) {
                # force the invalid issuer
                if ($arg_ref->{FORCE_ISSUER}) {
                    CTX('log')->log(
                        MESSAGE  => "Importing certificate with invalid chain with force! $cert_identifier / " . $cert->get_subject(),
                        PRIORITY => 'warn',
                        FACILITY => ['audit','system']
                    );
                } else {
                    OpenXPKI::Exception->throw(
                        message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_BUILD_CHAIN',
                        params  => { ISSUER_IDENTIFIER => $issuer_cert->{IDENTIFIER}, ISSUER_SUBJECT => $issuer_cert->{SUBJECT} },
                    ) ;
                }
            }

            $db_hash->{ISSUER_IDENTIFIER} = $issuer_cert->{IDENTIFIER};

            # if the issuer is in a realm, it forces the entity into the same one
            if ($issuer_cert->{PKI_REALM}){
                $db_hash->{PKI_REALM} = $issuer_cert->{PKI_REALM};
            }

        } elsif ($arg_ref->{FORCE_NOCHAIN}) {
            CTX('log')->log(
                MESSAGE  => "Importing certificate without issuer! $cert_identifier / " . $cert->get_subject(),
                PRIORITY => 'warn',
                FACILITY => ['audit','system']
            );
        } else {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_FIND_ISSUER',
                params  => { QUERY => Dumper $issuer_query },
            );
        }
    } # end of issuer validation

    # we now have a filled db_hash

    if ($do_update) {
        $dbi->update(
            TABLE => 'CERTIFICATE',    # use hash method
            DATA  => $db_hash,
            WHERE => { IDENTIFIER => $db_hash->{IDENTIFIER} }
        );
    } else {
        $dbi->insert(
            TABLE => 'CERTIFICATE',    # use hash method
            HASH  => $db_hash,
        );
    }
    $dbi->commit();
    # unset data to save bytes and return the remainder of the hash
    delete $db_hash->{DATA};
    return $db_hash;

}


=head2 import_chain( { DATA, FORMAT, PKI_REALM, IMPORT_ROOT, FORCE_NOCHAIN })

Expects a set of certificates as PKCS7 container, concated PEM or array
of PEM blocks - expected sorting is "entity first". For security reasons 
the root is not imported by default, set IMPORT_ROOT => 1 to import root 
certificates. If the chain can not be build, the import will fail unless 
you set FORCE_NOCHAIN => 1, which will import the chain as far as it can 
be built. Certificates from the chain that are already in the database 
are ignored. If the data contain certs from different chains, all chains 
are built (works only with PEM array/block yet!)

Return value is a hash with keys imported and failed. Imported contains 
the db_hash of the successful imports, failed contains the cert_identifier
and error message of failed imports ([{cert_identifier, error}]). 

=cut

sub import_chain {
    
    my $self    = shift;
    my $arg_ref = shift;

    my $default_token = CTX('api')->get_default_token();
    my $dbi = CTX('dbi_backend');

    my $realm = $arg_ref->{PKI_REALM};
    
    if (!$realm) {
        $realm = CTX('session')->get_pki_realm();
    }

    my @chain;
    if (ref $arg_ref->{DATA} eq 'ARRAY') {
        @chain = @{$arg_ref->{DATA}};
        
        CTX('log')->log(
            MESSAGE  => "Importing chain from array",
            PRIORITY => 'debug',
            FACILITY => 'system'
        );
        
    } elsif ( $arg_ref->{DATA} =~ /-----BEGIN PKCS7-----/ ) {
    # extract the entity certificate from the pkcs7     
        my $chainref = $default_token->command({
            COMMAND     => 'pkcs7_get_chain',        
            PKCS7       => $arg_ref->{DATA},
        });
        @chain = @{$chainref};
        
        CTX('log')->log(
            MESSAGE  => "Importing chain from pkcs7",
            PRIORITY => 'debug',
            FACILITY => 'system'
        );
                
    } else {
        
        @chain = ($arg_ref->{DATA} =~ m/(-----BEGIN CERTIFICATE-----[^-]+-----END CERTIFICATE-----)/gm);        
        
        CTX('log')->log(
            MESSAGE  => "Importing chain from pem block",
            PRIORITY => 'debug',
            FACILITY => 'system'
        );
    }

    my @imported;
    my @failed;
    my @exist;
    # We start at the end of the list
    CERT:
    while (my $pem = pop @chain) {

        my $cert = OpenXPKI::Crypto::X509->new(
            TOKEN => $default_token,
            DATA  => $pem,
        );
    
        my $cert_identifier = $cert->get_identifier();

        # Check if the certificate is already in the PKI
        my $db_hash = $dbi->first(
            TABLE   => 'CERTIFICATE',
            DYNAMIC => { IDENTIFIER => $cert_identifier }
        );

        if ($db_hash) {
            CTX('log')->log(
                MESSAGE  => "Certificate $cert_identifier already in database, skipping",
                PRIORITY => 'debug',
                FACILITY => 'system'
            );
            push @exist, $db_hash;
            delete $db_hash->{DATA};  
            next CERT;
        }
        
        # Check if it is a root certificate
        my $self_signed = 0;
        if (defined $cert->get_subject_key_id()
            && defined $cert->get_authority_key_id()) {
            if ($cert->get_subject_key_id() eq $cert->get_authority_key_id()) {
                $self_signed = 1;
            }    
        # certificates without AIK/SK set
        } else {
            if ($cert->{PARSED}->{BODY}->{SUBJECT} ne $cert->{PARSED}->{BODY}->{ISSUER}) {
                $self_signed = 1;                
            }
        }
        
        # Handle root certs 
        if ($self_signed && !$arg_ref->{IMPORT_ROOT}) {
            # do not import root
            CTX('log')->log(
                MESSAGE  => "Certificate $cert_identifier is self-signed, skipping",
                PRIORITY => 'debug',
                FACILITY => 'system'
            ); 
            next CERT;
        }
        
        # If we are here, we know that the cert does not exist and is 
        # either not a root or root import is allowed, we now call the 
        # import_certificate method for this item which also does the 
        # chain validation
        eval {
            my $db_insert = $self->import_certificate({ DATA => $pem, PKI_REALM => $realm, FORCE_NOCHAIN => $arg_ref->{FORCE_NOCHAIN}});
            push @imported, $db_insert;
            CTX('log')->log(
                MESSAGE  => "Certificate $cert_identifier imported with success",
                PRIORITY => 'info',
                FACILITY => 'system'
            ); 
        };
        if ($EVAL_ERROR) {
            my $ee = $EVAL_ERROR;
            CTX('log')->log(
                MESSAGE  => "Certificate $cert_identifier imported failed with " . $ee,
                PRIORITY => 'error',
                FACILITY => 'system'
            ); 
            push @failed, { cert_identifier => $cert_identifier, error => "$ee" };
        }

    }
    
    return { imported => \@imported, failed => \@failed, existed => \@exist };

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
OUTFORMAT, which can be either 'PEM', 'DER' or 'HASH' (full db result).
Returns a hash ref with the following entries:

    IDENTIFIERS   the chain of certificate identifiers as an array
    SUBJECT       list of subjects for the returned certificates
    CERTIFICATES  the certificates as an array of data in outformat
                  (if requested)
    COMPLETE      1 if the complete chain was found in the database
                  0 otherwise

By setting "BUNDLE => 1" you will not get a hash but a PKCS7 encoded bundle
holding the requested certificate and all intermediates (if found). Add
"KEEPROOT => 1" to also have the root in PKCS7 container.

