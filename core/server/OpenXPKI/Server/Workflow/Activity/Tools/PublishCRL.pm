package OpenXPKI::Server::Workflow::Activity::Tools::PublishCRL;

use Moose;
use MooseX::NonMoose;
extends qw( OpenXPKI::Server::Workflow::Activity );
with qw( OpenXPKI::Server::Workflow::Role::Publish );

use English;

use MIME::Base64;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypt::X509;
use Workflow::Exception qw(configuration_error workflow_error);

__PACKAGE__->mk_accessors( qw( crl_profile  ) );

sub __get_targets_from_profile {

    my $self = shift;
    my $profile = $self->crl_profile() || 'default';
    ##! 16: 'Load targets from profile '. $profile
    my @target = CTX('config')->get_scalar_as_list( [ 'crl', $profile, 'publish' ] );
    return \@target;

}

sub execute {

    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $config   = CTX('config');
    my $pki_realm = CTX('session')->data->pki_realm;

    my $dbi = CTX('dbi');

    my $ca_alias = $self->param('ca_alias') // $context->param('ca_alias');
    my $crl_serial = $self->param('crl_serial') // $context->param('crl_serial');

    if (!$crl_serial) {
        configuration_error('You must set crl_serial to an existing serial number or the special value *latest*');
    }

    if (!$ca_alias) {
        configuration_error('You must pass ca_alias');
    }

    my $certificate = CTX('api2')->get_certificate_for_alias( 'alias' => $ca_alias );
    my $ca_identifier = $certificate->{identifier};

    my $crl;
    # auto detect the latest one
    if ($crl_serial eq 'latest') {

        # Load the crl data
        $crl = $dbi->select_one(
            from => 'crl',
            columns => [ '*' ],
            where => {
                pki_realm => $pki_realm,
                issuer_identifier => $ca_identifier,
                profile => undef,
            },
            order_by => '-last_update',
        );

        # can happen for external CAs or if new tokens did not create a crl yet
        if (!$crl && $self->param('empty_ok')) {
            CTX('log')->system()->info("CRL publication skipped for $ca_identifier - no crl found");
            return;
        }

        $crl_serial = $crl->{crl_key};

    } else {

        # Load the crl data
        $crl = $dbi->select_one(
            from => 'crl',
            columns => [ '*' ],
            where => {
                crl_key => $crl_serial,
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

    if (!$crl || !$crl->{data}) {
        workflow_error('Unable to load CRL for publishing');
    }

    $self->crl_profile( $crl->{profile} );
    my ($prefix, $target) = $self->__fetch_targets(['publishing','crl']);

    # no targets returned
    return unless ($target);

    ##! 16: "Start publishing - CRL Serial $crl_serial , ca alias $ca_alias"

    # split of group and generation from alias
    $ca_alias =~ /^(.*)-(\d+)$/;

    my $data = {
        pem => $crl->{data},
        alias => $ca_alias,
        group => $1,
        generation => $2,
    };

    if ($crl->{data} =~ m{-----BEGIN\ ([^-]+)-----\s*(.*)\s*-----END\ \1-----}xms) {
        $data->{der} = decode_base64($2);
    }

    if (!defined $data->{der} || $data->{der} eq '') {
        workflow_error('Failed to convert CRL to DER');        
    }

    my $x509_issuer = OpenXPKI::Crypt::X509->new( $certificate->{data} );
    # Get Issuer Info from selected ca
    $data->{issuer} = $x509_issuer->subject_hash();
    $data->{subject} = $x509_issuer->get_subject();
    $data->{subject_key_identifier} = $x509_issuer->get_subject_key_id();
            
    my $failed = $self->__walk_targets( $prefix, $target, $data->{issuer}{CN}[0], $data, {} );
    
    # pause stops execution of the remaining code
    $self->pause('I18N_OPENXPKI_UI_ERROR_DURING_PUBLICATION') if ($failed);
     
    # Set the publication date in the database, only if not set already
    if (!$crl->{publication_date}) {
        $dbi->update(
            table => 'crl',
            set => { publication_date => DateTime->now()->epoch() },
            where => { crl_key => $crl_serial }
        );

        CTX('log')->system()->info("CRL publication date set for crl $crl_serial");

    }

    ##! 4: 'end'
    return;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::PublishCRLs

=head1 Description

This activity publishes a single crl. The parameters crl_serial and ca_alias
must be set either via activity parameters or exist in the context.
I<crl_serial> can have the value "latest" which will resolve to the crl with
the highest last_update date for the issuer created by the default profile.

The list of targets can be defined via an activity parameter or is read from
the CRL profile definition (see below). In either case each connector is
called with the CN of the issuing ca as location. The data portion contains
a hash ref with the keys I<pem>, I<der> and I<subject> (issuer subject)
holding the appropriate strings and I<issuer> which is the issuer subject
parsed into a hash as used in the template processing when issuing the
certificates.

There are several options to handle errors when the connectors fail,
details are given below (see I<on_error> parameter).

=head2 Publication by Profile (default)

The publishing information is read from the connector at crl.<profile>.publish
which must be a list of names (scalar is also ok). If the CRL to publish has
no profile set (which is the default), crl.default.publish is used. Each
name is expanded to the path publishing.crl.<name> which must be a
connector reference.

B<Note>: Contrary to certificate publication I<crl.default.publish> is only
used if the crl has no profile but it is not used as a global fallback if
there is no publication defined for the profile!

=head2 Publication without Profile

Instead of reading the publication targets from the profile you can point
the activity directly to a list of connectors by setting I<prefix> to the
base path of a hash. Each key is the internal name of the target, the value
must be a connector reference.

=head1 Configuration

=head2 Example

   publish_crl_action:
       class: OpenXPKI::Server::Workflow::Activity::Tools::PublishCRL
       prefix: publishing.crl

=head2 Activity parameters

=over

=item prefix / target

Enables publishing to a fixed set of connectors, disables per
profile settings. Base path fot I<target> is I<publishing.crl>

See OpenXPKI::Server::Workflow::Role::Publish

=item on_error

Define what to do on problems with the publication connectors.
See OpenXPKI::Server::Workflow::Role::Publish

=item crl_serial

The serial of the crl to publish or the keyword "latest" which pulls the
CRL with the latest last_update date for the given issuer which was
created with the default profile. Has precedence over the context item.

=item ca_alias

The alias name of the CA. Has precedence over the context item.

=item empty_ok

Boolean, only used in conjunction with crl_serial = latest. Will silently
skip publication of no CRL is found for the given issuer.

=back

=head2 Context parameters

=over

=item ca_alias

The alias name of the CA. Activity parameter has precedence!

=item crl_serial

The serial of the crl to publish or the keyword "latest" which pulls the
CRL with the latest last_update date for the given issuer.
Activity parameter has precedence!

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
