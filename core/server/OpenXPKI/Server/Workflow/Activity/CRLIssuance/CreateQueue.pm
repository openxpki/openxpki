# OpenXPKI::Server::Workflow::Activity::CRLIsssuance::CreateQueue
# Written by Oliver Welter for the OpenXPKI project 2012
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CRLIssuance::CreateQueue;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

use OpenXPKI::Server::Workflow::WFObject::WFArray;

use DateTime;


sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $pki_realm  = CTX('api')->get_pki_realm();
    my $context   = $workflow->context();

    my $config = CTX('config');

    my $ca_alias_list = OpenXPKI::Server::Workflow::WFObject::WFArray->new({
        workflow => $workflow,
        context_key => 'ca_alias_list',
    });

    # Determine the name of the key group for cert signing
    my $group_name = $config->get("crypto.type.certsign");
    my $active_ca_token = CTX('api')->list_active_aliases( { GROUP => $group_name } );

    ##! 32: "Active tokens found " . Dumper $active_ca_token

    # Force is, schedule all cas
    if ($context->param('force_issue')) {
        #! 8: 'Force update on all cas'
        foreach my $ca (@{$active_ca_token}) {
            $ca_alias_list->push($ca->{ALIAS});
        }
        CTX('log')->application()->info("Forced CRL update requested on realm $pki_realm");
        return 1;
    }

    ##! 8: 'Check for certificates'
    # Check for fresh revocations
    my $sth = CTX('dbi')->select(
        from => 'certificate',
        columns => [ -distinct => 'issuer_identifier' ],
        where => {
            pki_realm => $pki_realm,
            status => 'CRL_ISSUANCE_PENDING',
        },
    );
    my %ca_identifier;
    while (my $entry = $sth->fetchrow_hashref) {
        ##! 16: ' ca has revoked certificates pending ' . $entry->{'CERTIFICATE.ISSUER_IDENTIFIER'}
        CTX('log')->application()->debug('ca has revoked certificates pending ' . $entry->{issuer_identifier});

        $ca_identifier{$entry->{issuer_identifier}} = 1;
    }

    my $default_renew = $config->get("crl.default.validity.renewal");
    if (!$default_renew || !OpenXPKI::DateTime::is_relative($default_renew)) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CRLISSUANCE_CREATEQUEUE_RENEWAL_NOT_GIVEN_OR_NOT_RELATIVE",
            params => { REALM => $pki_realm, RENEW => $default_renew }
        );
    }

    # We trick a bit here - we set now + renewal and compare that against nextupdate
    # (its the same as nextupdate - renew > now )
    my $default_renewal = OpenXPKI::DateTime::get_validity(
        {
        VALIDITY => $default_renew,
        VALIDITYFORMAT => 'relativedate',
        },
    );

    # Check latest crl for each issuer
    foreach my $ca (@{$active_ca_token}) {

        ##! 16: ' Probing '. $ca->{IDENTIFIER}
        if ($ca_identifier{ $ca->{IDENTIFIER} }) {
            ##! 32: ' ca '. $ca->{IDENTIFIER} .' already scheduled - skip checks '
            $ca_alias_list->push($ca->{ALIAS});
            next;
        }

        my $renewal;
        # Check if there is a named profile
        my $profile_renewal = $config->get("crl.".$ca->{ALIAS}.".validity.renewal");
        if ($profile_renewal) {
            $renewal = OpenXPKI::DateTime::get_validity({
                VALIDITY => $profile_renewal,
                VALIDITYFORMAT => 'relativedate',
            });
        } else {
            $renewal = $default_renewal;
        }

        my $crl = CTX('dbi')->select_one(
            from => 'crl',
            columns => [ 'issuer_identifier', 'next_update' ],
            where => {
                pki_realm => $pki_realm,
                issuer_identifier => $ca->{IDENTIFIER},
                next_update => { '>' => $renewal->epoch() },
            },
        );

        if ($crl) {
            ##! 32: ' ca '. $ca->{IDENTIFIER} .' has crl beyond next renewal date '
            CTX('log')->application()->debug(' ca '. $ca->{IDENTIFIER} .' has crl beyond next renewal date ');

            next;
        }

        ##! 16: ' ca '. $ca->{IDENTIFIER} .' near expiry - updating'
        $ca_alias_list->push($ca->{ALIAS});

    }

}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CRLIssuance::CreateQueue

=head1 Description

Iterate over all CAs in the current realm and check if they need to issue a
new CRL. A list of the ca token alias names is written to the context as
I<ca_alias_list>. A ca is added to the list if there are certificates in
status CRL_ISSUANCE_PENDING or if the validty date of the latest crl is in
the configured renewal interval (I<realm.crl.validity.renewal>).

If the I<force_issue> flag is present in the context, each ca which is
currently valid, will issue a new crl.
