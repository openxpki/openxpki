## OpenXPKI::Server::Notification::Handler
##
## Written 2013 by Oliver Welter for the OpenXPKI project
## (C) Copyright 2013 by The OpenXPKI Project

=head1 NAME

 OpenXPKI::Server::Notification::Handler

=head1 Description

Interface to the new notification system. Checks the requested
notification against all configured backends and starts the
delivery according to the configuration.

=head1 Methods

=head2 notify({ MESSAGE, WORKFLOW })

Execute the notifcations for MESSAGE and.

=cut

package OpenXPKI::Server::Notification::Handler;

use strict;
use warnings;
use English;

use Data::Dumper;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Moose;

# Attribute Setup

has '_backends' => (
    is  => 'ro',
    isa => 'HashRef',
    builder => '_init_backends',
);

has 'serializer' => (
    is  => 'ro',
    isa => 'Object',
    default => sub { my $ser = OpenXPKI::Serialization::Simple->new(); return $ser; },
    lazy => 1,
);

# The handler is invoke during startup and initializes backends for all realms
sub _init_backends {

    ##! 1: 'start'
    my $self = shift;
    my @realms = CTX('config')->get_keys('system.realms');
    my $backends;
    foreach my $realm (@realms) {
        ##! 8: 'load realm $realm'
        CTX('session')->data->pki_realm( $realm );
        $backends->{$realm} = $self->_init_backends_for_realm();
    }

    return $backends;
}

sub _init_backends_for_realm {

    my $self = shift;
    my $config = CTX('config');
    my @backends = $config->get_keys('notification');

    my $backends_loaded;

    INIT_BACKEND:
    foreach my $backend (@backends) {

        my $class = $config->get("notification.$backend.backend.class");

        if (!$class) {
            CTX('log')->system()->error("No class set for notification backend $backend");

            next INIT_BACKEND;
        }

        eval "use $class;1";

        if ($EVAL_ERROR) {
            CTX('log')->system()->error("Initialization of Notification backend failed: $backend / $EVAL_ERROR");
            next INIT_BACKEND;
        }

        $backends_loaded->{$backend} = $class->new({ 'config' => "notification.$backend" });

    }

    return $backends_loaded;
}

=head2 notify({MESSAGE, WORKFLOW, TOKEN, DATA})

Public method to trigger a notification. MESSAGE is the name of
the message to be triggered, WORKFLOW is a reference to the workflow object
and TOKEN can contain persisted information from earlier calls of the same
notification thread. DATA can contain additional info to be passed to the template.

The vars hash passed to the templates is composed from the data extracted from the
workflow (@see _prepare_template_vars) and the data from the DATA variable, which
is added under the key "data".

=cut

sub notify {

    ##! 'start'

    my $self = shift;
    my $params = shift;

    my $workflow = $params->{WORKFLOW};
    my $token =  $params->{TOKEN};
    my $data =  $params->{DATA};
    $data = {} unless ($data);

    ##! 16: 'Got token ' . Dumper $token

    my $realm = CTX('session')->data->pki_realm;
    my $backends = $self->_backends()->{$realm};

    if (!$backends) { return; }

    my $vars = $self->_prepare_template_vars( $workflow );
    $vars->{data} = $data;

    ##! 16: 'Got backends ' . Dumper $backends
    foreach my $backend (keys %{$backends}) {

        # Add the tokens for this backend to the arguments

        my $ret = $backends->{$backend}->notify( {
            MESSAGE => $params->{MESSAGE},
            VARS => $vars,
            TOKEN => $token->{$backend},
            WORKFLOW => $workflow, # usually not necessary
        } );

        # Set the token to the return value (if not undef)
        $token->{$backend} = $ret if (defined $ret);

    }

    ##! 16: 'Return updated token ' . Dumper $token
    return $token;

}

=head2 _prepare_template_vars ( WORKFLOW )

Creates a hashref containing useful values from the realm and the workflow.

=over

=item realm info, from I<system.realms>

    meta_pki_realm, meta_label, meta_baseurl

=item scalar values from the context

    csr_serial, cert_subject, cert_identifier, cert_profile

=item hashes from the context

    cert_subject_parts, cert_subject_alt_name, cert_info, approvals

=item misc

    requestor (real name of the requestor, assembled from cert_info.requestor_gname + requestor_name)

=back

=cut

sub _prepare_template_vars {

    ##! 1: 'start'
    my $self = shift;
    my $workflow = shift;

    my $ser = $self->serializer();

    my $template_vars;
    # Name and Url of the Realm
    my $realm = CTX('session')->data->pki_realm;
    $template_vars->{'meta_pki_realm'} = $realm;
    $template_vars->{'meta_label'} = CTX('config')->get("system.realms.$realm.label");
    $template_vars->{'meta_baseurl'} = CTX('config')->get("system.realms.$realm.baseurl");

    # We might use the notification for non-workflow issues
    if ($workflow) {

        # Feed workflow information
        $template_vars->{meta_wf_id} = $workflow->id();
        $template_vars->{meta_wf_type} = $workflow->type();
        $template_vars->{meta_wf_state} = $workflow->state();

        my $context = $workflow->context();
        foreach my $key (qw(creator csr_serial cert_subject cert_identifier cert_profile )) {
            my $val = $context->param( $key );
            $template_vars->{$key} = $val if ($val);
        }

        # Load Subject Parts
        ##! 64: 'Testing cert_subject_parts ' . $context->param('cert_subject_parts')
        if (my $cert_subject_parts = $context->param('cert_subject_parts')) {
            $template_vars->{'cert_subject_parts'} =  $ser->deserialize( $cert_subject_parts );
        }

        # Load SAN
        ##! 64: 'Testing cert_subject_alt_name ' . $context->param('cert_subject_alt_name')
        if (my $san_info = $context->param('cert_subject_alt_name')) {
            $template_vars->{'cert_subject_alt_name'} =  $ser->deserialize( $san_info );
        }

        # Load the requestor info fields
        ##! 64: 'Testing cert_info ' . $context->param('cert_info')
        if (my $cert_info = $context->param('cert_info')) {
            $template_vars->{'cert_info'} = $ser->deserialize( $cert_info );
        }

        # Load the approvals info fields
        ##! 64: 'Testing approvals ' . $context->param('approvals')
        if (my $approvals = $context->param('approvals')) {
            $template_vars->{'approvals'} = $ser->deserialize( $approvals );
        }


        # Shortcut
        $template_vars->{'requestor'} = 'unknown';
        $template_vars->{'requestor'} = $template_vars->{'cert_info'}->{requestor_gname}.' ' if ($template_vars->{'cert_info'}->{requestor_gname});
        $template_vars->{'requestor'} .= $template_vars->{'cert_info'}->{requestor_name}.' ' if ($template_vars->{'cert_info'}->{requestor_name});
    }

    ##! 32: 'template vars ' . Dumper $template_vars

    return $template_vars;

}

1;
