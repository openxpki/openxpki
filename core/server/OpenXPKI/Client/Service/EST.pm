package OpenXPKI::Client::Service::EST;
use Moose;

use Carp;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use MIME::Base64;
use Feature::Compat::Try;
use OpenXPKI::Exception;
use OpenXPKI::Crypt::X509;
use OpenXPKI::Client::Service::Response;

extends 'OpenXPKI::Client::Service::Base';


sub handle_revocation_request {

    my $self = shift;
    my $cgi = shift;
    my $operation = shift || $self->operation();

    my $config = $self->config();
    my $log = $self->logger();

    my $conf = $config->config();

    my $param = $self->build_params( $operation, $cgi );

    if (!defined $param) {
        return OpenXPKI::Client::Service::Response->new( 50010 );
    }

    # preset reason code if not already done from wrapper config
    $param->{reason_code} = 'unspecified' unless(defined $param->{reason_code});

    my $payload = $cgi->param( 'POSTDATA' );
    try{
        my $x509 = OpenXPKI::Crypt::X509->new( decode_base64($payload) );
        $param->{certificate} = $x509->pem;
    } catch ($error) {
        return OpenXPKI::Client::Service::Response->new( 40002 );
    }

    my $workflow_type = $conf->{$operation}->{workflow} ||
        'certificate_revoke';
    $log->debug( 'Start workflow type ' . $workflow_type );
    $log->trace( 'Workflow Paramters '  . Dumper $param );

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

around 'build_params' => sub {

    my $orig = shift;
    my $self = shift;
    my @args = @_;

    my $params = $self->$orig(@args);

    return unless($params); # something is wrong

    # TODO this should be merged with the stuff in Base without
    # having protocol specific items in the core code
    if ($self->operation() =~ m{simple((re)?enroll|revoke)}) {
        $params->{'server'} = $self->config()->endpoint();
        $params->{'interface'} = $self->config()->service();
        $params->{'signer_cert'} = $ENV{SSL_CLIENT_CERT} if ($ENV{SSL_CLIENT_CERT});
    }

    $self->logger->trace(Dumper $params);
    return $params;
};

__PACKAGE__->meta->make_immutable;

 __END__;
