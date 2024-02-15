package OpenXPKI::Client::Service::EST;
use Moose;

with 'OpenXPKI::Client::Service::Base';

sub service_name { 'est' }

# Core modules
use Carp;
use English;
use Data::Dumper;
use MIME::Base64;

# CPAN modules
use Log::Log4perl qw(:easy);
use Feature::Compat::Try;

# Project modules
use OpenXPKI::Exception;
use OpenXPKI::Crypt::X509;
use OpenXPKI::Client::Service::Response;


sub custom_wf_params {
    my $self = shift;
    my $params = shift;

    # TODO this should be merged with the stuff in Base without
    # having protocol specific items in the core code
    if ($self->operation =~ m{simple((re)?enroll|revoke)}) {
        $params->{'server'} = $self->endpoint;
        $params->{'interface'} = $self->service_name;
        if (my $signer = $self->apache_env->{SSL_CLIENT_CERT}) {
            $params->{'signer_cert'} = $signer;
        }
    }

    return 1;
}

sub handle_revocation_request {

    my $self = shift;

    my $log = $self->logger;
    my $param = $self->wf_params
        or return OpenXPKI::Client::Service::Response->new( 50010 );

    # preset reason code if not already done from wrapper config
    $param->{reason_code} = 'unspecified' unless defined $param->{reason_code};

    my $body = $self->request->body
        or do {
            $log->debug( 'Incoming revocation request with empty body' );
            return OpenXPKI::Client::Service::Response->new( 40003 );
        };

    try {
        my $x509 = OpenXPKI::Crypt::X509->new( decode_base64($body) );
        $param->{certificate} = $x509->pem;
    } catch ($error) {
        return OpenXPKI::Client::Service::Response->new( 40002 );
    }

    my $workflow_type = $self->config->{simplerevoke}->{workflow} || 'certificate_revoke';
    $log->debug( 'Start workflow type ' . $workflow_type );
    $log->trace( 'Workflow Paramters '  . Dumper $param ) if $self->logger->is_trace;

    my $response = $self->run_workflow($workflow_type, $param);

    if ($response->has_error) {
        # noop
    } elsif ($response->state eq 'SUCCESS') {
        $response->http_status_code(204);
    } elsif ($response->state eq 'CANCELED') {
        $response->http_status_code(409);
    } else {
        $response->http_status_code(400);
    }
    return $response;
}

# required by OpenXPKI::Client::Service::Base
sub prepare_enrollment_result {

    my $self = shift;
    my $workflow = shift;
    # not used for the default case
    # my $operation = shift;

    my $result = $self->backend()->run_command('get_cert',{
        format => 'PKCS7',
        identifier => $workflow->{context}->{cert_identifier},
    });

    $result =~ s{-----(BEGIN|END) PKCS7-----}{}g;
    $result =~ s{\s}{}gxms;

    return OpenXPKI::Client::Service::Response->new(
        result => $result,
        workflow => $workflow,
    );

}

__PACKAGE__->meta->make_immutable;

 __END__;
