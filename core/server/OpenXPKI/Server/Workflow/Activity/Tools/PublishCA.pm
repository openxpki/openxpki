package OpenXPKI::Server::Workflow::Activity::Tools::PublishCA;

use Moose;
use MooseX::NonMoose;
extends qw( OpenXPKI::Server::Workflow::Activity );
with qw( OpenXPKI::Server::Workflow::Role::Publish );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypt::X509;
use Workflow::Exception qw(configuration_error workflow_error);


sub __get_targets_from_profile {
    # there is no default for CA publishing -> exception
    configuration_error("You must provide target or prefix for CA publishing");
}

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $config        = CTX('config');
    my $pki_realm = CTX('session')->data->pki_realm;

    my ($prefix, $target) = $self->__fetch_targets(['publishing','cacert']);

    # no targets returned
    return unless ($target);

    my $ca_alias = $context->param('ca_alias') || configuration_error('No ca alias found for ca publish');

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
    my $certificate = CTX('api2')->get_certificate_for_alias( 'alias' => $ca_alias );
    my $x509 = OpenXPKI::Crypt::X509->new( $certificate->{data} );

    # Get Issuer Info from selected ca
    $data->{dn} = $x509->subject_hash();
    $data->{subject} = $x509->get_subject();
    $data->{subject_key_identifier} = $x509->get_subject_key_id();

    $data->{pem} = $x509->pem();
    $data->{der} = $x509->data();

    my $failed = $self->__walk_targets( $prefix, $target, $data->{dn}{CN}[0], $data );

    # pause stops execution of the remaining code
    $self->pause('I18N_OPENXPKI_UI_ERROR_DURING_PUBLICATION') if ($failed);

    ##! 4: 'end'
    return;
}

__PACKAGE__->meta->make_immutable;

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

=item prefix / target

Enables publishing to a fixed set of connectors, disables per
profile settings. Base path fot I<target> is I<publishing.cacert>

See OpenXPKI::Server::Workflow::Role::Publish

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
