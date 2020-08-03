package OpenXPKI::Server::Workflow::Activity::Tools::PublishCRL;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::DN;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Crypt::X509;
use Workflow::Exception qw(configuration_error workflow_error);

use Data::Dumper;

sub execute {

    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $config   = CTX('config');
    my $pki_realm = CTX('session')->data->pki_realm;

    my $dbi = CTX('dbi');

    my $default_token = CTX('api2')->get_default_token();
    my $prefix = $self->param('prefix') || '';
    my $ca_alias = $self->param('ca_alias') // $context->param('ca_alias');
    my $crl_serial = $self->param('crl_serial') // $context->param('crl_serial');

    if (!$crl_serial) {
        configuration_error('You must set crl_serial to an existing serial number or the special value *latest*');
    }

    if (!$ca_alias) {
        configuration_error('You must pass ca_alias');
    }

    my $certificate = CTX('api2')->get_certificate_for_alias( 'alias' => $ca_alias );
    my $x509_issuer = OpenXPKI::Crypt::X509->new( $certificate->{data} );
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
    $data->{issuer} = $x509_issuer->subject_hash();
    $data->{subject} = $x509_issuer->get_subject();
    $data->{subject_key_identifier} = $x509_issuer->get_subject_key_id();


    my @target;
    my @prefix = ('publishing', 'crl');

    if ($prefix) {
        @prefix = split ( /\./, $prefix );
        ##! 16: 'Load targets using prefix '. $prefix
        @target = $config->get_keys( \@prefix );
    } else {
        my $profile = $crl->{profile} || 'default';
        ##! 16: 'Load targets from profile '. $profile
        @target = $config->get_scalar_as_list( [ 'crl', $profile, 'publish' ] );
    }

    if ( $context->param( 'tmp_publish_queue' ) ) {
        my $queue =  $context->param( 'tmp_publish_queue' );
        ##! 16: 'Overwrite targets from context queue'
        if (!ref $queue) {
            $queue  = OpenXPKI::Serialization::Simple->new()->deserialize( $queue );
        }
        @target = @{$queue};
    }


    # Some connectors return a one item array with an empty element
    ##! 32: 'Targets ' . Dumper \@target
    return unless (@target && $target[0]);

    my $on_error = $self->param('on_error') || '';
    my @failed;

    foreach my $target (@target) {
        ##! 16: 'Start publishing to ' . $target
        eval{ $config->set( [ @prefix, $target, $data->{issuer}{CN}[0] ], $data ); };
        if (my $eval_err = $EVAL_ERROR) {
            ##! 16: 'failed with error ' . $eval_err
            CTX('log')->application()->debug("Publishing failed with $eval_err");
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
            CTX('log')->application()->info("CRL pubication to $target for $crl_serial done");
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

This activity publishes a single crl. The parameters crl_serial and ca_alias
must be set either via activity parameters or exist in the context.
I<crl_serial> can have the value "latest" which will resolve to the crl with
the highest last_update date for the issuer created by the default profile.

The list of targets can be defined via an activity parameter or is read from
the CRl profile definition (see below). In either case each connector is
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
the activity directly to a list of connectors setting I<prefix> to the base
path of a hash. Each key is the internal name of the target, the value must
be a connector reference.

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
