package OpenXPKI::Server::Notification::Connector;

use Moose;
extends 'OpenXPKI::Server::Notification::Base';

use English;

use Data::Dumper;
use JSON;
use YAML::Loader;
use DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

has 'backend' => (
    is => 'ro',
    isa => 'Object',
    reader => '_backend',
    builder => '_init_backend',
    lazy => 1,
);

has '_json' => (
    is => 'ro',
    isa => 'JSON',
    default => sub { return JSON->new(); },
    lazy => 1,
);

sub _init_backend {

    my $self = shift;

    ##! 8: 'creating transport'
    my $cfg = CTX('config')->get_hash( $self->config() . '.backend' );

    my $class = $cfg->{connector};
    delete $cfg->{class}; # this is the notify package name
    delete $cfg->{connector}; # this is the connector package name

    eval "use $class;1" or OpenXPKI::Exception->throw(
        message => 'Unable to load connector backend class',
        params  => {
            class => $class,
            error => $@,
        });

    my $conn;
    eval{ $conn = $class->new(%{$cfg}); };
    if ($EVAL_ERROR || !$conn) {
        OpenXPKI::Exception->throw(
        message => 'Unable to initialize connector backend class',
        params  => {
            class => $class,
            error => $@,
        });
    }

    return $conn;
}

=head1 Functions
=head2 notify
see @OpenXPKI::Server::Notification::Base
=cut
sub notify {

    ##! 1: 'start'

    my $self = shift;
    my $args = shift;

    my $msg = $args->{MESSAGE};
    my $token = $args->{TOKEN};
    my $template_vars = $args->{VARS};

    my $msgconfig = $self->config().'.message.'.$msg;

    # Test if there is an entry for this kind of message
    my @handles = CTX('config')->get_keys( $msgconfig );

    ##! 8: 'Starting message ' . $msg

    ##! 16: 'Found handles ' . Dumper @handles

    ##! 32: 'Template vars: ' . Dumper $template_vars

    if (!@handles) {
        CTX('log')->system()->debug("No notifcations to send for $msgconfig");
        return 0;
    }

    # Walk through the handles
    QUEUE_HANDLE:
    foreach my $handle (@handles) {

        my $pi = $token->{$handle};

        ##! 16: 'Starting handle '.$handle.', PI: ' . Dumper $pi

        # We do the eval per handle
        eval {
            my @path = CTX('config')->get_scalar_as_list( "$msgconfig.$handle.path" );

            # template defines a YAML file that is rendered using TT
            my $template_file = CTX('config')->get( "$msgconfig.$handle.template" );

            my $data;
            if ($template_file) {
                ##! 32: "Using template file $template_file"
                my $yaml = $self->_render_template_file( $template_file.'.yaml', $template_vars );
                ##! 64: $yaml
                $data = YAML::Loader->new->load($yaml);
            } elsif (my $content = CTX('config')->get_hash( "$msgconfig.$handle.content" )) {
                my %vars = %{$template_vars};
                ##! 32: "Using content hash with key " . join(", ", keys %($content))
                ##! 64: $content
                # we use template toolkit on any scalar value that contains a % sign
                foreach my $key (keys %{$content}) {
                    my $value = $content->{$key} || '';
                    if (!ref $value && ($value =~ m{%}))  {
                        $value = $self->_render_template( $value, \%vars );
                    }
                    $data->{$key} = $value;
                }
            }

            if (!$data) {
                CTX('log')->system()->warn("Unable to generate message for $handle - no data");
                next QUEUE_HANDLE;
            }

            ##! 32: $data
            ##! 64: "Notify to path " . join(".", @path)
            ##! 64: $data
            CTX('log')->system()->trace(sprintf("Notify to %s with payload %s",
                join(".", @path), Dumper $data)) if (CTX('log')->system()->is_trace());

            my $json = $self->_json()->encode($data);
            die "Unable to encode to json" unless($json);
            $self->_backend()->set(\@path, $json);

        };
        if ($EVAL_ERROR) {
            CTX('log')->system()->error("Notify for $msgconfig/$handle failed with $EVAL_ERROR");
        }
    } # end handle

    return $token;

}

sub _cleanup {

}

__PACKAGE__->meta->make_immutable;

=head1 NAME

OpenXPKI::Server::Notification::Connector - Notification via Connector

=head1 DESCRIPTION

This class implements a notifier that sends out notifications via the "set"
method of a Connector backend. The payload can be created in different ways.

For now this backend supports creation of a data structure directly as a hash
from the config or by rendering a YAML file using Template Toolkit and parsing
the yaml afterwards.

The only supported output format for now is JSON.

=head1 Configuration

# Sample configuration using a JSON based REST API via HTTP

backend:
    class: OpenXPKI::Server::Notification::Connector
    connector: Connector::Proxy::HTTP
    LOCATION: https://api.acme.org/v2/
    content_type: application/json
    http_method: POST
    header:
        Authorization: MyAuthToken

# template settings
template:
    dir:   /etc/openxpki/template/alerts/

message:
    cert_expiry:
        default:
            path: alert
            # the template file must end on .yaml and generate a hash
            template: cert_expiry

    cert_issued:
        default:
            path: info
            content:
                title: A new certificate for [% cert_subject %] has been created
                message: |
                    A new certificate for [% cert_subject %] has been created.
                    You can find more details on the PKI WebUI.
                priority: info
