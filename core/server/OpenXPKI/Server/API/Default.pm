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
use OpenXPKI::MooseParams;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::i18n qw( set_language );
use Digest::SHA qw( sha1_base64 );
use DateTime;
use Workflow;

use OpenXPKI::Server::Database::Legacy;

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
    my $sess_lang = CTX('session')->data->language;
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
    return CTX('session')->data->pki_realm;
}

# get current user
sub get_user {
    return CTX('session')->data->user;
}

# get current user
sub get_role {
    return CTX('session')->data->role;
}

sub get_session_info {

    my $self    = shift;

    my $session = CTX('session');
    return {
        name => $session->data->user,
        role => $session->data->role,
        role_label => CTX('config')->get([ 'auth', 'roles', $session->data->role, 'label' ]),
        pki_realm => $session->data->pki_realm,
        pki_realm_label => CTX('config')->get([ 'system', 'realms', $session->data->pki_realm, 'label' ]),
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

# Test: qatest/backend/api/12_get_chain.t
sub get_chain {
    my ($self, $args) = @_;

    my $default_token;

    my $cert_list = [];
    my $id_list = [];
    my $subject_list = [];
    my $finished = 0;
    my $complete = 0;
    my %already_seen; # hash of identifiers that have already been seen

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_SERVER_API_GET_CHAIN_START_IDENTIFIER_MISSING",
    ) unless $args->{START_IDENTIFIER};
    my $start = $args->{START_IDENTIFIER};
    my $current_identifier = $start;
    my $dbi = CTX('dbi');

    my $outer_format = $args->{OUTFORMAT} || '';
    my $inner_format = $args->{BUNDLE} ? 'PEM' : $outer_format;

    while (! $finished) {
        ##! 128: '@identifiers: ' . Dumper(\@identifiers)
        ##! 128: '@certs: ' . Dumper(\@certs)
        push @$id_list, $current_identifier;
        my $cert = $dbi->select_one(
            from => 'certificate',
            columns => [ '*' ],
            where => {
                identifier => $current_identifier,
            },
        );
        # stop if certificate was not found
        last unless $cert;

        push @$subject_list, $cert->{subject};

        if ($inner_format) {
            if ($inner_format eq 'PEM') {
                push @$cert_list, $cert->{data};
            }
            elsif ($inner_format eq 'DER') {
                $default_token = CTX('api')->get_default_token() unless($default_token);
                my $utf8fix = $default_token->command({
                    COMMAND => 'convert_cert',
                    DATA    => $cert->{data},
                    IN      => 'PEM',
                    OUT     => 'DER',
                });
                push @$cert_list, $utf8fix;
            }
            elsif ($inner_format eq 'HASH') {
                # remove data to save some bytes
                delete $cert->{data};

                # TODO #legacydb Mapping for compatibility to old DB layer
                push @$cert_list, OpenXPKI::Server::Database::Legacy->certificate_to_legacy($cert);
            }
        }
        if ($cert->{issuer_identifier} eq $current_identifier) {
            # self-signed, this is the end of the chain
            $complete = 1;
            last;
        }
        else { # go to parent
            $current_identifier = $cert->{issuer_identifier};
            ##! 64: 'issuer: ' . $current_identifier
            last if $already_seen{$current_identifier}; # we've run into a loop!
            $already_seen{$current_identifier} = 1;
        }
    }

    # Return a pkcs7 structure instead of the hash
    if ($args->{BUNDLE}) {

        # we do NOT include the root in p7 bundles
        pop @$cert_list if ($complete and !$args->{KEEPROOT});

        $default_token = CTX('api')->get_default_token() unless($default_token);
        my $result = $default_token->command({
            COMMAND          => 'convert_cert',
            DATA             => $cert_list,
            OUT              => ($outer_format eq 'DER' ? 'DER' : 'PEM'),
            CONTAINER_FORMAT => 'PKCS7',
        });
        return $result;
    }

    return {
        SUBJECT     => $subject_list,
        IDENTIFIERS => $id_list,
        COMPLETE    => $complete,
        $outer_format ? (CERTIFICATES => $cert_list) : (),
    };
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

=head2 import_certificate

Parameters:

=over

=item * B<DATA>, certificate data (PEM encoded)

=item * B<PKI_REALM> (optional), set the PKI realm to this value (might be overridden by an
issuer's realm)

=item * B<FORCE_NOCHAIN> (optional), 1 = import certificate even if issuer is
unknown (then I<issuer_identifier> will not be set) or has an incomplete
signature chain.

=item * B<FORCE_ISSUER> (optional), 1 = enforce import even if it has an invalid
signature chain (i.e. verification failed).

=item * B<FORCE_NOVERIFY> (optional), 1 = do not validate signature chain (e.g.
if one of the certificates' CA has expired)

=item * B<REVOKED> (optional), Set to 1 to set the certificate status to "REVOKED"

=item * B<UPDATE> (optional), Do not throw an exception if certificate already exists, update it instead

=back

=cut

sub import_certificate {
    my $self    = shift;
    my $arg_ref = shift;

    if ($arg_ref->{ISSUER} and $arg_ref->{FORCE_NOCHAIN}) {
        # TODO Use unique exception id instead of text and output command line specific hints in openxpkiadm
        OpenXPKI::Exception->throw(
            message => 'Option force-no-chain is not allowed with explicit issuer, use force-issuer instead!'
        );
    }

    my $dbi = CTX('dbi');
    my $default_token = CTX('api')->get_default_token();

    my $cert = OpenXPKI::Crypto::X509->new(
        TOKEN => $default_token,
        DATA  => $arg_ref->{DATA},
    );
    my $cert_identifier = $cert->get_identifier();

    # Check if the certificate is already in the PKI
    my $existing_cert = $dbi->select_one(
        from => 'certificate',
        columns => [ qw( identifier pki_realm status ) ],
        where => { identifier => $cert_identifier },
    );

    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_CERTIFICATE_ALREADY_EXISTS',
        params  => {
            IDENTIFIER => $existing_cert->{identifier},
            PKI_REALM => $existing_cert->{pki_realm} || '',
            STATUS => $existing_cert->{status},
        },
    ) if ($existing_cert and not $arg_ref->{UPDATE});

    # Prepare hash to be inserted into DB
    my $cert_legacy = { $cert->to_db_hash() };
    $cert_legacy->{STATUS} = ($arg_ref->{REVOKED} ? 'REVOKED' : 'ISSUED');
    $cert_legacy->{PKI_REALM} = $arg_ref->{PKI_REALM} if ($arg_ref->{PKI_REALM});

    # Query issuer certificate
    my $issuer_cert = $self->_get_issuer(
        cert            => $cert,
        explicit_issuer => $arg_ref->{ISSUER},
        force_nochain   => $arg_ref->{FORCE_NOCHAIN},
    );

    # cert is self signed
    if ($issuer_cert and $issuer_cert eq "SELF") {
        $cert_legacy->{ISSUER_IDENTIFIER} = $cert_identifier;
    }
    # cert has known issuer
    elsif ($issuer_cert) {
        my $valid;
        #
        # No verfication requested ?
        #
        if ($arg_ref->{FORCE_NOVERIFY}) {
            CTX('log')->system()->warn("Importing certificate without chain verification! $cert_identifier / " . $cert->get_subject);
            CTX('log')->audit('system')->warn('certificate import without chain validation', {
                certid    => $cert_identifier,
                key       => $cert->get_subject_key_id(),
            });
            $valid = 1;
        }
        else {
            $valid = $self->_is_issuer_valid(
                default_token  => $default_token,
                cert           => $cert,
                issuer_cert    => $issuer_cert,
                force_nochain  => $arg_ref->{FORCE_NOCHAIN},
            );
        }

        if (!$valid) {
            # force the invalid issuer
            if ($arg_ref->{FORCE_ISSUER}) {
                CTX('log')->system->warn("Importing certificate with invalid chain with force! $cert_identifier / " . $cert->get_subject());
                CTX('log')->audit('system')->warn('certificate import without chain validation', {
                    certid    => $cert_identifier,
                    key       => $cert->get_subject_key_id(),
                });
            } else {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_BUILD_CHAIN',
                    params  => { ISSUER_IDENTIFIER => $issuer_cert->{identifier}, ISSUER_SUBJECT => $issuer_cert->{subject} },
                );
            }
        }

        $cert_legacy->{ISSUER_IDENTIFIER} = $issuer_cert->{identifier};
        # if the issuer is in a realm, it forces the entity into the same one
        $cert_legacy->{PKI_REALM} = $issuer_cert->{pki_realm} if $issuer_cert->{pki_realm};
    }

    # TODO #legacydb Mapping for compatibility to old DB layer
    my $cert_hash = OpenXPKI::Server::Database::Legacy->certificate_from_legacy($cert_legacy);

    $dbi->merge(
        into => 'certificate',
        set => $cert_hash,
        where => { identifier => $cert_hash->{identifier} },
    );

    # unset data to save bytes and return the remainder of the hash
    delete $cert_legacy->{DATA};

    return $cert_legacy;
}

# Returns the certificate issuer DB hash or C<"SELF"> if it's self signed or
# C<undef> if no issuer was found (and force_nochain = 1).
sub _get_issuer {
    my ($self, %args) = named_args(\@_,   # OpenXPKI::MooseParams
        cert            => { isa => 'OpenXPKI::Crypto::X509' },
        explicit_issuer => { isa => 'Maybe[Str]' },
        force_nochain   => { isa => 'Maybe[Bool]' },
    );
    my $cert            = $args{cert};
    my $cert_identifier = $cert->get_identifier;
    my $explicit_issuer = $args{explicit_issuer};
    my $force_nochain   = $args{force_nochain};

    my $condition;

    #
    # Check for self signed certificate
    #

    # Check if self-signed based on Key Ids, if set
    if (defined $cert->get_subject_key_id and defined $cert->get_authority_key_id) {
        # TODO Handle case where get_authority_key_id() returns HashRef
        $condition = { subject_key_identifier => $cert->get_authority_key_id };
        # self signed
        return "SELF" if $cert->get_subject_key_id() eq $cert->get_authority_key_id;

    # certificates without AIK/SK set
    } else {
        $condition = { subject => $cert->{PARSED}->{BODY}->{ISSUER} };
        # self signed
        return "SELF" if $cert->{PARSED}->{BODY}->{SUBJECT} eq $cert->{PARSED}->{BODY}->{ISSUER};
    }

    #
    # Lookup issuer if not self-signed
    #

    # Explicit issuer wins over issuer query
    $condition = { identifier => $explicit_issuer } if $explicit_issuer;

    # TODO - check for non-uniq subjects
    my $db_result = CTX('dbi')->select(
        from  => 'certificate',
        columns => [ '*' ],
        where => $condition,
    );
    my $issuer_cert = $db_result->fetchrow_hashref;

    # No issuer found
    if (not $issuer_cert) {
        if ($force_nochain) {
            CTX('log')->system()->warn("Importing certificate without issuer! $cert_identifier / " . $cert->get_subject());
            return;
        }
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_FIND_ISSUER',
            params  => { QUERY => Dumper $condition },
        );
    }

    # More than 1 query result
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_ISSUER_QUERY_AMBIGIOUS_RESULT',
        params  => {
            RESULT_COUNT => scalar @{$db_result},
            QUERY => Dumper $condition,
        },
    ) if $db_result->fetchrow_arrayref;

    return $issuer_cert;
}

sub _is_issuer_valid  {
    my ($self, %args) = named_args(\@_,   # OpenXPKI::MooseParams
        default_token  => { isa => 'Object' },
        cert           => { isa => 'OpenXPKI::Crypto::X509' },
        issuer_cert    => { isa => 'HashRef' },
        force_nochain  => { isa => 'Maybe[Bool]' },
    );
    my $default_token   = $args{default_token};
    my $cert            = $args{cert};
    my $cert_identifier = $cert->get_identifier;
    my $issuer_cert     = $args{issuer_cert};
    my $force_nochain   = $args{force_nochain};

    #
    # If issuer is already a root
    #
    if ($issuer_cert->{identifier} eq $issuer_cert->{issuer_identifier}) {
        return $default_token->command({
            COMMAND => 'verify_cert',
            CERTIFICATE => $cert->{DATA},
            TRUSTED => $issuer_cert->{data},
        });
    }

    #
    # If issuer is no root, get the chain starting from the issuer
    #

    # validate_certificate
    my $chain = $self->get_chain({ START_IDENTIFIER => $issuer_cert->{identifier}, OUTFORMAT => 'PEM' });

    # verify a complete chain
    if ($chain->{COMPLETE}) {
        my @work_chain = @{$chain->{CERTIFICATES}};
        my $root = pop @work_chain;

        return $default_token->command({
            COMMAND => 'verify_cert',
            CERTIFICATE => $cert->{DATA},
            TRUSTED => $root,
            CHAIN => join "\n", @work_chain
        });
    }

    # Accept an incomplete chain
    if ($force_nochain) {
        CTX('log')->system()->warn("Importing certificate with incomplete chain! $cert_identifier / " . $cert->get_subject());
        return 1;
    }

    return 0;
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
    my ($self, $arg_ref) = @_;

    my $default_token = CTX('api')->get_default_token();
    my $realm = $arg_ref->{PKI_REALM} || CTX('session')->data->pki_realm;

    my @chain;
    if (ref $arg_ref->{DATA} eq 'ARRAY') {
        @chain = @{$arg_ref->{DATA}};
        CTX('log')->system()->debug("Importing chain from array");
    }
    # extract the entity certificate from the pkcs7
    elsif ($arg_ref->{DATA} =~ /-----BEGIN PKCS7-----/) {
        my $chainref = $default_token->command({
            COMMAND     => 'pkcs7_get_chain',
            PKCS7       => $arg_ref->{DATA},
        });
        @chain = @{$chainref};
        CTX('log')->system()->debug("Importing chain from PKCS7");

    }
    # expect PEM block
    else {
        @chain = ($arg_ref->{DATA} =~ m/(-----BEGIN CERTIFICATE-----[^-]+-----END CERTIFICATE-----)/gm);
        CTX('log')->system()->debug("Importing chain from PEM block");
    }

    my @imported;
    my @failed;
    my @exist;
    my $dbi = CTX("dbi");

    # We start at the end of the list
    while (my $pem = pop @chain) {
        my $cert = OpenXPKI::Crypto::X509->new(
            TOKEN => $default_token,
            DATA  => $pem,
        );
        my $cert_identifier = $cert->get_identifier();

        # Check if the certificate is already in the PKI
        my $cert_hash = $dbi->select_one(
            from => 'certificate',
            columns => [ '*' ],
            where => { identifier => $cert_identifier },
        );

        if ($cert_hash) {
            CTX('log')->system()->debug("Certificate $cert_identifier already in database, skipping");
            delete $cert_hash->{DATA};
            # TODO #legacydb Mapping for compatibility to old DB layer
            push @exist, OpenXPKI::Server::Database::Legacy->certificate_to_legacy($cert_hash);
            next;
        }

        # Check if root certificate
        my $self_signed = (defined $cert->get_subject_key_id and defined $cert->get_authority_key_id)
            ? ($cert->get_subject_key_id eq $cert->get_authority_key_id)
            : ($cert->{PARSED}->{BODY}->{SUBJECT} eq $cert->{PARSED}->{BODY}->{ISSUER});

        # Do not import root certs unless specified
        if ($self_signed and !$arg_ref->{IMPORT_ROOT}) {
            CTX('log')->system()->debug("Certificate $cert_identifier is self-signed, skipping");
            next;
        }

        # Now we know that the cert does not exist and is either not a root cert
        # or root import is allowed. We now call "import_certificate" which also
        # does the chain validation
        eval {
            my $db_insert = $self->import_certificate({
                DATA => $pem,
                PKI_REALM => $realm,
                FORCE_NOCHAIN => $arg_ref->{FORCE_NOCHAIN},
            });
            push @imported, $db_insert;
            CTX('log')->system()->info("Certificate $cert_identifier imported with success");
        };
        if (my $eval_err = $EVAL_ERROR) {
            if (ref $eval_err eq 'OpenXPKI::Exception') {
                $eval_err = $eval_err->message;
            }
            CTX('log')->system()->error("Certificate $cert_identifier imported failed with $eval_err");
            push @failed, { cert_identifier => $cert_identifier, error => $eval_err };
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

