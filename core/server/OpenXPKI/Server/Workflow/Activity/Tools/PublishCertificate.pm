# OpenXPKI::Server::Workflow::Activity::Tools::PublishCertificate
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::PublishCertificate;

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
    my $context = $workflow->context();

    my $default_token = CTX('api')->get_default_token();
    my $config        = CTX('config');

    my $cert_identifier = $self->param('cert_identifier');

    if (!$cert_identifier) {
        $cert_identifier = $context->param('cert_identifier');
    }

    if (!$cert_identifier) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CERTIFICATE_USING_PROFILE_NO_CERT_IDENTIFIER'
        );
    }

    my @target;
    my @path;
    # Detect if we are in profile or prefix mode
    my $prefix = $self->param('prefix');
    if (defined $prefix) {
        if (!$prefix || !$config->exists( $prefix )) {
            CTX('log')->application()->debug('Publication in prefix mode but prefix not set or empty');

            return 1;
        }

        @path = split /\./, $prefix;
        # Get the list of targets from prefix
        @target = $config->get_keys( $prefix );

    } else {

        # Profile mode

        ##! 16: 'Lookup profile for identifier ' . $cert_identifier
        my $profile = CTX('api')->get_profile_for_cert({ IDENTIFIER => $cert_identifier });

        if (!$profile) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CERTIFICATE_NO_PROFILE_FOR_CERTIFICATE',
                params => { 'CERT_IDENTIFIER' => $cert_identifier },
            );
        }

        # Check if the node exists inside the profile

        if ($config->exists([ 'profile', $profile, 'publish'])) {
            @target = $config->get_scalar_as_list( [ 'profile', $profile, 'publish'] );
        } else {
            @target = $config->get_scalar_as_list( [ 'profile', 'default', 'publish'] );
        }

        # Reuse the prefix value to build the full path
        @path = ( 'publishing','entity' );

    }

    # If the data point does not exist, we get a one item undef array
    return unless (@target && $target[0]);


    ##! 16: 'Start publishing - load certificate for identifier ' . $cert_identifier

    # Load and convert the certificate
    my $cert = CTX('dbi')->select_one(
        from => 'certificate',
        columns => [ 'data', 'subject' ],
        where => {
           identifier => $cert_identifier,
        },
    );

    if (!$cert || !$cert->{data}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CERTIFICATE_UNABLE_TO_LOAD_CERTIFICATE',
            params => { 'CERT_IDENTIFIER' => $cert_identifier },
        );
    }

    CTX('log')->application()->debug('Publication for ' . $cert->{subject} . ', targets ' . join(",", @target));


    # Prepare the data
    my $data = {};
    $data->{pem} = $cert->{data};
    $data->{subject} = $cert->{subject};

    # Convert to DER
    $data->{der} = $default_token->command({
        COMMAND => 'convert_cert',
        DATA    => $data->{pem},
        OUT     => 'DER',
    });

    if (!defined $data->{der} || $data->{der} eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CERTIFICATES_COULD_NOT_CONVERT_CERT_TO_DER',
        );
    }

    # Check for publication key
    my $publish_key = $self->param('publish_key');

    # Defined but empty, stop publication
    if (defined($publish_key) && !$publish_key) {
        CTX('log')->application()->info('Dont publish as publish_key is defined but empty for ' .$data->{subject});

        return 1;
    }

    # No publication key set, parse out CN
    if (!$publish_key) {
        # Strip the common name to be used as publishing key
        my $dn_parser = OpenXPKI::DN->new( $data->{subject} );
        my %rdn_hash = $dn_parser->get_hashed_content();

        # something went wrong - no CN set?
        if (!$rdn_hash{CN}[0]) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CERTIFICATES_UNABLE_TO_PARSE_SUBJECT',
            );
        }
        $publish_key = $rdn_hash{CN}[0];
    }


    ##! 32: 'Data for publication '. Dumper ( $data )

    CTX('log')->application()->info('Start publication to '.$publish_key.' for ' .$data->{subject});


    # Required for special connectors (grabbing extended data from the workflow)
    # TODO: should be replaced by e.g. a static factory
    my $param;
    if ($self->param('export_context')) {
       $param->{extra} = $workflow->context()->param();
       ##! 16: 'Export context to connector ' . Dumper $param
    }

    # overwrite targets when we are in the wake up loop
    if ( $context->param( 'tmp_publish_queue' ) ) {
        my $queue =  $context->param( 'tmp_publish_queue' );
        ##! 16: 'Load targets from context queue'
        if (!ref $queue) {
            $queue  = OpenXPKI::Serialization::Simple->new()->deserialize( $queue );
        }
        @target = @{$queue};
    }

    my $on_error = $self->param('on_error') || '';
    my @failed;
    ##! 32: 'Targets ' . Dumper \@target
    foreach my $target (@target) {
        eval{ $config->set( [ @path, $target, $publish_key ], $data, $param ); };
        if (my $eval_err = $EVAL_ERROR) {
            if ($on_error eq 'queue') {
                push @failed, $target;
                CTX('log')->application()->info("Entity pubication failed for target $target, requeuing");

            } elsif ($on_error eq 'skip') {
                CTX('log')->application()->warn("Entity pubication failed for target $target and skip is set");

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
            CTX('log')->application()->debug("Entity pubication to $target for ". $publish_key." done");

        }
    }

    if (@failed) {
        $context->param( 'tmp_publish_queue' => \@failed );
        $self->pause('I18N_OPENXPKI_UI_ERROR_DURING_PUBLICATION');
        # pause stops execution of the remaining code
    }

    $context->param( { 'tmp_publish_queue' => undef });

    ##! 4: 'end'
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::PublishCertificate

=head1 Description

This class publishes a single certificate based on the publishing information
associated with the certificate profile or a given prefix. The certificate is
identified by the parameter cert_identifier which can be set in the action
definition. If unset, the class falls back to the context value of cert_identifier.

The publishing information is read from the connector at profile.<profile name>.publish
which must be a list of names (scalar is also ok). If the node does not exists,
profile.default.publish is used. Each name is expanded to the path
publishing.entity.<name> which must be a connector reference. The publication
target is taken from the parameter I<publish_key> or defaults to the certificates
common name (CN attribute parsed from the final subject). The data portion
contains a hash ref with the keys I<pem>, I<der> and I<subject> (full dn of the cert).
Note: if the evaluation of I<publish_key> is empty but defined, the publication
is stopped.

To use profile independant publication, specify the parameter I<prefix> which must
point to a scalar/list of connector references.

=head1 Configuration

Set the wanted connector names in the certificates profile:

  publish:
    - extldap
    - exthttp

Define the connector references and implementations in publishing.yaml

  entity:
      extldap@: connector: publishing.connectors.ext-ldap
      exthttp@: connector: publishing.connectors.ext-http

  connectors:
    ext-ldap:
      class: Connector::Proxy::Net::LDAP::Single
      LOCATION: ldap://localhost:389
      ....

=head2 Activity parameters

=over

=item prefix

Enables publishing to a fixed set of connectors, disables per profile settings.

=item cert_identifier

Set the identifier of the cert to publish, optional, default is the value
of the context key cert_identifier.

=item publish_key

The value to be used as key for the publication call, optional.
E.g. to publish using the context value with key "user_email" set
this to "$user_email".

=item export_context

Boolean, if set the full context is passed to the connector in the third argument.

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
