# OpenXPKI::Server::Workflow::Activity::Tools::PublishCA
# Copyright (c) 2015 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::PublishCA;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::DN;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $config        = CTX('config');
    my $pki_realm = CTX('session')->data->pki_realm;

    if (!$self->param('prefix')) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CA_NO_PREFIX'
        );
    }

    my $default_token = CTX('api')->get_default_token();
    my $prefix = $self->param('prefix');
    my $ca_alias = $context->param('ca_alias');

    if (!$ca_alias) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CA_NO_CA_ALIAS'
        );
    }

    ##! 16: "Start publishing - ca alias $ca_alias"

    # split of group and generation from alias
    $ca_alias =~ /^(.*)-(\d+)$/;

    my $data = {
        alias => $ca_alias,
        group => $1,
        generation => $2,
    };

    # Load issuer info
    # FIXME - this might be improved using some caching
    my $certificate = CTX('api')->get_certificate_for_alias( { 'ALIAS' => $ca_alias });
    my $x509 = OpenXPKI::Crypto::X509->new(
        DATA  => $certificate->{DATA},
        TOKEN => $default_token,
    );

    # Get Issuer Info from selected ca
    $data->{dn} = $x509->{PARSED}->{BODY}->{SUBJECT_HASH};
    $data->{subject} = $self->{PARSED}->{BODY}->{SUBJECT};

    $data->{pem} = $x509->get_converted('PEM');
    $data->{der} = $x509->get_converted('DER');

    if (!defined $data->{der} || $data->{der} eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CA_COULD_NOT_CONVERT_CERT_TO_DER',
        );
    }

    my @target;
    my @prefix = split /\./, $prefix;

    # overwrite targets when we are in the wake up loop
    if ( $context->param( 'tmp_publish_queue' ) ) {
        my $queue =  $context->param( 'tmp_publish_queue' );
        ##! 16: 'Load targets from context queue'
        if (!ref $queue) {
            $queue  = OpenXPKI::Serialization::Simple->new()->deserialize( $queue );
        }
        @target = @{$queue};
    } else {
        @target = $config->get_keys( \@prefix );
    }

    # If the data point does not exist, we get a one item undef array
    return unless ($target[0]);

    my $on_error = $self->param('on_error') || '';
    my @failed;
    ##! 32: 'Targets ' . Dumper \@target
    foreach my $target (@target) {
        eval{ $config->set( [ @prefix, $target, $data->{dn}{CN}[0] ], $data ); };
        if (my $eval_err = $EVAL_ERROR) {
            if ($on_error eq 'queue') {
                push @failed, $target;
                CTX('log')->application()->info("CA pubication failed for target $target, requeuing");

            } elsif ($on_error eq 'skip') {
                CTX('log')->application()->warn("CA pubication failed for target $target and skip is set");

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
            CTX('log')->application()->debug("CA pubication to $target for ". $data->{dn}{CN}[0]." done");

        }
    }

    if (@failed) {
        $context->param( 'tmp_publish_queue' => \@failed );
        $self->pause('I18N_OPENXPKI_UI_ERROR_DURING_PUBLICATION');
        # pause stops execution of the remaining code
    }

    $context->param( { 'tmp_publish_queue' => undef });


    ##! 4: 'end'
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::PublishCA

=head1 Description

This activity publishes a single ca certificate. The context must hold the
ca_alias parameter. The data point you specify at prefix must contain
a list of connectors. Each connector is called with the CN of the certificate
as location. The data portion contains a hash ref with the keys I<pem>, I<der>
and I<subject> holding the appropriate strings and I<dn> which is the subject
parsed into a hash as used in the template processing when issuing the certificates.

=head1 Configuration

=head2 Example

Set the C<prefix> paramater to tell the activity where to find the connector

    publish_crl:
        class: OpenXPKI::Server::Workflow::Activity::Tools::PublishCA
        label: I18N_OPENXPKI_UI_WORKFLOW_ACTION_CRL_ISSUANCE_PUBLISH_CA_LABEL
        description: I18N_OPENXPKI_UI_WORKFLOW_ACTION_CRL_ISSUANCE_PUBLISH_CA_DESC
        input:
          - ca_alias
        param:
            prefix: publishing.cacert


Set up the connector using this syntax

  publishing:
    cacert:
      repo1@: connector:....
      repo2@: connector:....

To publish the certificate to your LDAP with autocreation of missing nodes,
here is an example connector:

    ldap-cacert:
        class: Connector::Proxy::Net::LDAP::Single
        LOCATION: ldap://localhost:389
        base: ou=pki,dc=mycompany,dc=com
        filter: (cn=[% ARGS.0 %])
        binddn: cn=admin,dc=mycompany,dc=com
        password: admin
        attrmap:
            der: cacertificate;binary

        create:
            basedn: ou=pki,dc=mycompany,dc=com
            rdnkey: cn

        schema:
            cn:
                objectclass: top organizationalRole pkiCA crlDistributionPoint

=head2 Activity parameters

=over

=item prefix

The config path where the connector configuration resides, in the default
configuration this is I<publishing.cacert>.

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

=back

=head2 Context parameters

=over

=item ca_alias

The alias name of the CA

=item tmp_publish_queue

Used to temporary store unpublished targets when on_error is set.

=back



