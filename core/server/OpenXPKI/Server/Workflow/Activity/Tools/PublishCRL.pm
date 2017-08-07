# OpenXPKI::Server::Workflow::Activity::Tools::PublishCRL
# Written by Oliver Welter for the OpenXPKI project 2012
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::PublishCRL;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::DN;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $config        = CTX('config');
    my $pki_realm = CTX('session')->data->pki_realm;

    my $dbi = CTX('dbi');

    if (!$self->param('prefix')) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CRL_NO_PREFIX'
        );
    }

    my $default_token = CTX('api')->get_default_token();
    my $prefix = $self->param('prefix');
    my $ca_alias = $context->param('ca_alias');
    my $crl_serial = $context->param('crl_serial');
    $crl_serial = $self->param('crl_serial') unless($crl_serial);

    if (!$ca_alias) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CRL_NO_CA_ALIAS'
        );
    }

    my $certificate = CTX('api')->get_certificate_for_alias( { 'ALIAS' => $ca_alias });
    my $x509_issuer = OpenXPKI::Crypto::X509->new(
        DATA  => $certificate->{DATA},
        TOKEN => $default_token,
    );

    my $ca_identifier = $certificate->{IDENTIFIER};

    if (!$crl_serial) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CRL_NO_CRL_SERIAL'
        );
    }

    my $crl;
    # auto detect the latest one
    if ($crl_serial eq 'latest') {

        # Load the crl data
        $crl = $dbi->select_one(
            from => 'crl',
            columns => [ '*' ],
            where => {
                pki_realm => $pki_realm,
                issuer_identifier => $ca_identifier
            },
            order_by => '-last_update',
        );

        # can happen for external CAs or if new tokens did not create a crl yet
        if (!$crl && $self->param('empty_ok')) {
            CTX('log')->system()->info("CRL publication skipped for $ca_identifier - no crl found");

            return;
        }

        $crl_serial = $crl->{crk_key};

    } else {

        # Load the crl data
        $crl = $dbi->select_one(
            from => 'crl',
            columns => [ '*' ],
            where => {
                crl_key => $crl_serial
            }
        );

        if ($crl && $crl->{issuer_identifier} ne $ca_identifier) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CRL_SERIAL_DOES_NOT_MATCH_ISSUER',
                params => {  CRL_SERIAL => $crl_serial, PKI_REALM => $pki_realm,
                    ISSUER => $crl->{issuer_identifier}, EXPECTED_ISSUER => $ca_identifier }
            );
        }

    }

    ##! 16: "Start publishing - CRL Serial $crl_serial , ca alias $ca_alias"

    if (!$crl || !$crl->{data}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CRL_UNABLE_TO_LOAD_CRL',
            params => { 'CRL_SERIAL' => $crl_serial },
        );
    }

    # split of group and generation from alias
    $ca_alias =~ /^(.*)-(\d+)$/;

    my $data = {
        pem => $crl->{data},
        alias => $ca_alias,
        group => $1,
        generation => $2,
    };

    # Convert to DER
    $data->{der} = $default_token->command({
        COMMAND => 'convert_crl',
        DATA    => $crl->{data},
        OUT     => 'DER',
    });

    if (!defined $data->{der} || $data->{der} eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CRL_COULD_NOT_CONVERT_CRL_TO_DER',
        );
    }


    # Get Issuer Info from selected ca
    $data->{issuer} = $x509_issuer->{PARSED}->{BODY}->{SUBJECT_HASH};
    $data->{subject} = $x509_issuer->{PARSED}->{BODY}->{SUBJECT};

    my @target;
    my @prefix = split ( /\./, $prefix );
    if ( $context->param( 'tmp_publish_queue' ) ) {
        my $queue =  $context->param( 'tmp_publish_queue' );
        ##! 16: 'Load targets from context queue'
        if (!ref $queue) {
            $queue  = OpenXPKI::Serialization::Simple->new()->deserialize( $queue );
        }
        @target = @{$queue};
    } else {
        ##! 16: 'Load all targets'
        @target = $config->get_keys( \@prefix );
    }

    my $on_error = $self->param('on_error') || '';
    my @failed;
    ##! 32: 'Targets ' . Dumper \@target
    foreach my $target (@target) {
        eval{ $config->set( [ @prefix, $target, $data->{issuer}{CN}[0] ], $data ); };
        if (my $eval_err = $EVAL_ERROR) {
            if ($on_error eq 'queue') {
                push @failed, $target;
                CTX('log')->application()->info("CRL pubication failed for target $target, requeuing");

            } elsif ($on_error eq 'skip') {
                CTX('log')->application()->warn("CRL pubication failed for target $target and skip is set");

            } else {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_PUBLICATION_FAILED',
                    params => {
                        TARGET => $target,
                        ERROR => $eval_err
                    }
                );
            }
        } else {
            CTX('log')->application()->debug("CRL pubication to $target for $crl_serial done");

        }
    }

    if (@failed) {
        $context->param( 'tmp_publish_queue' => \@failed );
        $self->pause('I18N_OPENXPKI_UI_ERROR_DURING_PUBLICATION');
        # pause stops execution of the remaining code
    }

    $context->param( { 'tmp_publish_queue' => undef });

    # Set the publication date in the database, only if not set already
    if (!$crl->{publication_date}) {
        $dbi->update(
            table => 'crl',
            set => { publication_date => DateTime->now()->epoch() },
            where => { crl_key => $crl_serial }
        );

        CTX('log')->system()->info("CRL pubication date set for crl $crl_serial");

    }

    ##! 4: 'end'
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::PublishCRLs

=head1 Description

This activity publishes a single crl. The context must hold the crl_serial
and the ca_alias parameters. I<crl_serial> can have the value "latest" which
will resolve to the crl with the highest last_update date for the issuer.

The data point you specify at prefix must contain a list of connectors.
Each connector is called with the CN of the issuing ca as location.
The data portion contains a hash ref with the keys I<pem>, I<der>
and I<subject> (issuer subject) holding the appropriate strings and
I<issuer> which is the issuer subject parsed into a hash as used in the
template processing when issuing the certificates.

There are severeal options to handle errors when the connectors fail,
details are given below (see I<on_error> parameter).

=head1 Configuration

=head2 Example

   publish_crl_action:
       class: OpenXPKI::Server::Workflow::Activity::Tools::PublishCRL
       prefix: publishing.crl

=head2 Activity parameters

=over

=item prefix

The config path where the connector configuration resides, in the default
configuration this is I<publishing.crl>.

=item on_error

Define what to do on problems with the publication connectors. One of:

=over

=item exception (default)

The connector exception bubbles up and the workflow terminates.

=item skip

Skip the publication target and continue with the next one.

=item queue

Similar to skip, but failed targets are added to a queue. As long as
the queue is not empty, pause/wake_up is used to retry those targets
with the retry parameters set. This obvioulsy requires I<retry_count>
to be set.

=back

=item crl_serial

The serial of the crl to publish or the keyword "latest" which pulls the
CRL with the latest last_update date for the given issuer. Only effective
if B<NOT> set in the context.

=item empty_ok

Boolean, only used in conjunction with crl_serial = latest. Will silently
skip publication of no CRL is found for the given issuer.

=back

=head2 Context parameters

=over

=item ca_alias

The alias name of the CA

=item crl_serial

The serial of the crl to publish or the keyword "latest" which pulls the
CRL with the latest last_update date for the given issuer.

=item tmp_publish_queue

Used to temporary store unpublished targets when on_error is set.

=back

=head2 Data Source Configuration

At the configuration path given in the I<prefix> parameter, you must
provide a list of connectors:

  publishing:
    crl:
      repo1@: connector:....
      repo2@: connector:....

To publish the crl to your webserver, here is an example connector:

    cdp:
        class: Connector::Builtin::File::Path
        LOCATION: /var/www/myrealm/
        file: "[% ARGS %].crl"
        content: "[% pem %]"

The ARGS placeholder is replaced with the CN part of the issuing ca. So if you
name your ca generations as "ServerCA-1" and "ServerCA-2", you will end up
with two crls at "http://myhost/myrealm/ServerCA-1.crl" resp.
"http://myhost/myrealm/ServerCA-2.crl"





