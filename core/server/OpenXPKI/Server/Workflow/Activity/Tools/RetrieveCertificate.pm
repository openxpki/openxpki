# OpenXPKI::Server::Workflow::Activity::Tools::RetrieveCertificate
# Written by Martin Bartosch for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::RetrieveCertificate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use DateTime;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

my @parameters = qw(
    cert_profile
    cert_subject
    min_remaining_validity
    valid_at
);

__PACKAGE__->mk_accessors(@parameters);

sub execute {
    my ($self, $workflow) = @_;
    my $pki_realm = CTX('session')->data->pki_realm;
    my $context = $workflow->context();

    ##! 16: 'RetrieveCertificate'
    my %contextentry_of = (
        certificateout => 'certificate',
        certidentifierout  => undef,
    );
    for my $contextkey (keys %contextentry_of) {
        if (defined $self->param($contextkey . 'contextkey')) {
            $contextentry_of{$contextkey} = $self->param($contextkey . 'contextkey');
        }
    }

    my $status_filter = $self->param('certstatus') // 'ISSUED';

    if ($status_filter !~ m{ \A (?: ISSUED | REVOKED | CRL_ISSUANCE_PENDING | ANY ) \z }xms) {
        OpenXPKI::Exception->throw(
           message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_RETRIEVECERTIFICATE_INVALID_CERTSTATUS_SPECIFICATION',
           params  => { status => $status_filter },
       );
    }

    # propagate workflow activity parametrisation to our object
    for my $arg (@parameters) {
        if (defined $self->param($arg)) {
            $self->$arg( $self->param($arg) );
        }
        # access worklow context instead of literal value if value starts
        # with a $
        if (defined $self->$arg() && ($self->$arg() =~ m{ \A \$ (.*) }xms)) {
            my $wf_key = $1;
            $self->$arg( $context->param($wf_key) );
        }
        ##! 64: 'param: ' . $arg . '; value: ' . $self->$arg()
    }

    unless ($self->cert_profile or $self->cert_subject) {
        ##! 16: 'operation mode 1 (search for certificate identifier)'
        my $cert_identifier = $context->param('cert_identifier');

        my %cert_status_condition;
        $cert_status_condition{status} = $status_filter
            unless $status_filter eq 'ANY';

        if (! defined $cert_identifier) {
            ##! 16: 'no certificate identifier specified, clearing context entry'
            $context->param($contextentry_of{'certificateout'} => undef);
            return 1;
        }

        ##! 16: 'searching for certificate identifier ' . $cert_identifier
        my $cert = CTX('dbi')->select_one(
            from => 'certificate',
            columns => [ 'data' ],
            where  => {
              identifier=> $cert_identifier,
              pki_realm => $pki_realm,
              %cert_status_condition,
            },
        );
        $context->param($contextentry_of{'certificateout'} => $cert->{data});
        return 1;
    }

    ##! 16: 'operation mode 2 (query certificate details)'
    my $valid_at = time; # default
    if (defined $self->valid_at) {
        if ($self->valid_at =~ m{ \A (\d{4})(\d{2})(\d{2}) \z }xms) {
            my $dt = DateTime->new(
                year      => $1,
                month     => $2,
                day       => $3,
                time_zone => 'UTC',
            );
            $valid_at = $dt->epoch;
        }
        elsif ($self->valid_at =~ m{ \A \d+ \z }xms) {
            $valid_at = $self->valid_at;
        }
        else {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_RETRIEVECERTIFICATE_INVALID_TIME_SPECIFICATION',
                params  => { valid_at => $self->valid_at },
            );
        }
    }
    if (defined $self->min_remaining_validity) {
        $valid_at = time + ($self->min_remaining_validity() * 24 * 3600);
    }

    my $cert = CTX('dbi')->select_one(
        from_join  => 'certificate req_key=req_key csr',
        columns => [
            'certificate.data',
            'certificate.identifier',
            'certificate.notafter',
        ],
        where => {
            'certificate.pki_realm' => $pki_realm,
            'certificate.notbefore' => { '<=', $valid_at },
            'certificate.notafter'  => { '>=', $valid_at },
            $self->cert_profile     ? ('csr.profile'         => $self->cert_profile) : (),
            $self->cert_subject     ? ('certificate.subject' => $self->cert_subject) : (),
            $status_filter ne 'ANY' ? ('certificate.status'  => $status_filter)      : (),
        },
        order_by => [ '-certificate.cert_key' ],
    );
    ##! 16: 'certificate found: ' . Dumper $cert

    if (not $cert) {
        ##! 16: 'no matching certs found'
        $context->param($contextentry_of{'certificateout'}    => undef);
        $context->param($contextentry_of{'certidentifierout'} => undef)
            if defined $contextentry_of{'certidentifierout'};
        return 1;
    }

    $context->param($contextentry_of{'certificateout'} => $cert->{data});
    $context->param($contextentry_of{'certidentifierout'} => $cert->{identifier})
        if defined $contextentry_of{'certidentifierout'};
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::RetrieveCertificate

=head1 Description

Searches certificate database for certificate with the matching criteria.

Activity configuration:
certificateoutcontextkey        context parameter to use for output certificate
                                (default: certificate)
certidentifieroutcontextkey     context parameter to use for output certificate
                                identifier
                                (default: none, do not write to context)

certstatus                      Only match certificates with the specified
                                status. May be one of the following:
                                ISSUED: certificate is not revoked (DEFAULT)
                                CRL_ISSUANCE_PENDING: certificate is revoked,
                                  but does not yet appear on any CRL
                                REVOKED: certificate is revoked
                                ANY: matches any certificate state


Operation mode 1: search for certificate identifier

If no activity options are specified this activity expects to find the
a context parameter cert_identifier. Its value is used to query the
database and search the corresponding certificate.

Sets context parameter 'certificate' to PEM encoded certificate with the
matching certificate identifier.


Operation mode 2: search for particular certificate with specified criteria

This operation mode is enabled if at least one of the following
activity parameters are defined in the activity definition. The
parameter cert_identifier is IGNORED if any of these parameters are
defined.

cert_profile:           filter certificates with this profile (required)
cert_subject:           filter certificates with specified subject
min_remaining_validity: filter certificates with a minimum of the specified
                        number of days remaining before expiration
valid_at:               filter certificates which are valid at specified
                        time (allowed: Unix timestamp or YYYYMMDD,
                        distinguished by value length)

Note: if parameters specified start with a '$', the corresponding workflow
context parameter is referenced instead of the literal string.

The first certificate with the matching criteria is exported via the
context parameter 'certificate' (PEM encoded).

Only if explicitly set in the activity configuration via
identifieroutcontextkey the specified context entry is set by the
activity to contain the retrieved certificate identifier.
