package OpenXPKI::Server::Workflow::Activity::Tools::PublishCertificate;

use Moose;
use MooseX::NonMoose;
extends qw( OpenXPKI::Server::Workflow::Activity );
with qw( OpenXPKI::Server::Workflow::Role::Publish );

use English;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypt::X509;
use Workflow::Exception qw(configuration_error workflow_error);


sub __get_targets_from_profile {

    my $self = shift;

    my $cert_identifier = $self->param('cert_identifier') //  $self->workflow()->context()->param('cert_identifier');

    ##! 16: 'Lookup profile for identifier ' . $cert_identifier
    my $profile = CTX('api2')->get_profile_for_cert( identifier => $cert_identifier );

    workflow_error("Given cert_identifier ($cert_identifier) was not found") unless($profile);

    # Check if the node exists inside the profile
    my $config_key = $self->param('unpublish') ? 'unpublish' : 'publish';
    my @target;
    if (CTX('config')->exists([ 'profile', $profile, $config_key ])) {
        @target = CTX('config')->get_scalar_as_list( [ 'profile', $profile, $config_key ] );
    } else {
        @target = CTX('config')->get_scalar_as_list( [ 'profile', 'default', $config_key ] );
    }

    return \@target;

}

sub execute {

    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context = $workflow->context();
    my $config        = CTX('config');

    my $cert_identifier = $self->param('cert_identifier') //  $context->param('cert_identifier');
    configuration_error('No cert_identifier was set') unless($cert_identifier);

    my ($prefix, $target) = $self->__fetch_targets(['publishing','entity']);

    # no targets returned
    return unless ($target);

    my $unpublish = $self->param('unpublish') || 0;
    ##! 16: 'Start publishing - load certificate for identifier ' . $cert_identifier

    my @cols = ('data', 'subject', 'identifier');
    push @cols, ('reason_code', 'revocation_time', 'invalidity_time') if ($unpublish);

    # Load and convert the certificate
    my $data = CTX('dbi')->select_one(
        from => 'certificate',
        columns => \@cols,
        where => {
           identifier => $cert_identifier,
           pki_realm => CTX('session')->data->pki_realm,
        },
    );

    if (!$data || !$data->{data}) {
        workflow_error('Unable to load given certificate in PublishCertificate');
    }

    # Prepare the data
    my $x509 = OpenXPKI::Crypt::X509->new( $data->{data} );
    if (!$x509) {
        workflow_error('Unable to parse certificate in PublishCertificate');
    }

    delete $data->{data};
    $data->{pem} = $x509->pem;
    $data->{der} = $x509->data;

    $data->{unpublish} = 1 if ($unpublish);

    # Check for publication key
    my $publish_key = $self->param('publish_key');

    # Defined but empty, stop publication
    if (defined($publish_key) && !$publish_key) {
        CTX('log')->application()->info('Dont publish as publish_key is defined but empty for ' .$data->{subject});
        return 1;
    }

    # No publication key set, parse out CN
    if (!$publish_key) {
        my $rdn_hash = $x509->subject_hash();
        $publish_key = $rdn_hash->{CN}->[0];
        # something went wrong - no CN set?
        workflow_error('Unable to parse subject or no commonName set') unless($publish_key);
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

    my $failed = $self->__walk_targets( $prefix, $target, $publish_key, $data, $param );

    # pause stops execution of the remaining code
    $self->pause('I18N_OPENXPKI_UI_ERROR_DURING_PUBLICATION') if ($failed);

    ##! 4: 'end'
    return 1;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::PublishCertificate

=head1 Description

Publish a single certificate based on the publishing information
associated with the certificate profile or a given prefix.

The certificate is identified by the parameter cert_identifier which can be set
in the action definition. If unset, the class falls back to the context value
of C<cert_identifier>.

=head2 Publication by Profile

The publishing information is read from the connector at profile.<profile name>.publish
which must be a list of names (scalar is also ok). If the node does not exists,
profile.default.publish is used. Each name is expanded to the path
publishing.entity.<name> which must be a connector reference. The publication
target is taken from the parameter I<publish_key> or defaults to the certificates
common name (CN attribute parsed from the final subject). The data portion
contains a hash ref with the keys I<pem>, I<der> and I<subject> (full dn of the cert).

Note: if the evaluation of I<publish_key> is empty but defined, the publication
is stopped.

=head2 Un-Publish

If you set I<unpublish> to a true value, the list of connectors is read from
the configuration at profile.<profile name>.unpublish (or
profile.default.unpublish).

The data portion is extended by the fields I<revocation_time>, I<reason_code>
and I<invalidity_time>. Fields are present even for non-revoked certificates.

=head2 Publication without Profile

Instead of reading the publication targets from the profile you can point
the activity directly to a list of connectors setting I<prefix> to the base
path of a hash. Each key is the internal name of the target, the value must
be a connector reference.

If I<unpublish> is set, the extra fields in data hash are present but the
list of targets remains the same.

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

=item prefix / target

Enables publishing to a fixed set of connectors, disables per
profile settings. Base path fot I<target> is I<publishing.entity>

See OpenXPKI::Server::Workflow::Role::Publish

=item cert_identifier

Set the identifier of the cert to publish, optional, default is the value
of the context key cert_identifier.

=item publish_key

The value to be used as key for the publication call, optional.
E.g. to publish using the context value with key "user_email" set
this to "$user_email".

=item unpublish

Boolean, adds revocation information and changes config node to read targets.

=item export_context

Boolean, if set the full context is passed to the connector in the third argument.

=item on_error

Define what to do on problems with the publication connectors.
See OpenXPKI::Server::Workflow::Role::Publish

=back
