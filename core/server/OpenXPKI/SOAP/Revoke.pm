# SOAP service implementing a certificate revocation interface

use strict;
use warnings;

package OpenXPKI::SOAP::Revoke;

use English;
use Config::Std;
use OpenXPKI::Exception;
use Data::Dumper;
use OpenXPKI::Client::Simple;
use OpenXPKI::Serialization::Simple;

use Log::Log4perl;

my $log = $main::config->logger();

$log->info("SOAP interface NG initialized ");

#$log->trace('Env ' . Dumper \%ENV);

sub __dispatch_revoke {

    my $class   = shift;
    my $arg     = shift;

    my $config = $main::config->config();

    my $client_ip   = $ENV{REMOTE_ADDR};    # dotted quad
    my $server_name = $ENV{SERVER_NAME};    # ca.company.com
    my $request_uri = $ENV{REQUEST_URI};    # "/soap/"

    my $canonical_uri = $server_name . $request_uri;

    my $auth_dn = '';
    my $auth_pem = '';
    if ( defined $ENV{HTTPS} && lc( $ENV{HTTPS} ) eq 'on' ) {

        $log->debug("calling context is https");
        $auth_dn = $ENV{SSL_CLIENT_S_DN};
        $auth_pem = $ENV{SSL_CLIENT_CERT};
        if ( defined $auth_dn ) {
            $log->info("SOAP Revoke authenticated client DN: $auth_dn");
        }
        else {
            $log->info("SOAP Revoke unauthenticated");
        }
    }
    else {
        $log->debug("calling context is http");
    }

    my $package = __PACKAGE__;

    # Workflow and endpoint name is held in the package config
    my $workflow_type = $config->{$package}->{workflow};
    my $servername = $config->{$package}->{servername};

    if ( !defined $workflow_type ) {
        $log->error("SOAP CertificateRevoke: Unable to read config / workflow type not set, url: $canonical_uri");
        return SOAP::Data->new( name => 'result', value => {
            error => 'Unable to read config / workflow type not set',
        });
    }

    my $crr_info = {
        requester_sn => $auth_dn || '',
        client_ip    => $client_ip,
    };

    my $workflow;
    my $client;
    eval {

        $client = OpenXPKI::Client::Simple->new({
            logger => $log,
            config => $config->{global}, # realm and locale
            auth => $config->{auth}, # auth config
        });

        if ( !$client ) {
            $log->error("Could not instantiate client object");
            return SOAP::Data->new( name => 'result', value => {
                error => 'Could not instantiate client object'
            });
        }

        # if revoke by serial is requested, use API to resolve the identifier
        if (!$arg->{cert_identifier}) {
            my $res = $client->run_command( 'search_cert', {
                CERT_SERIAL => $arg->{serial},
                ISSUER_DN   => $arg->{issuer_dn},
                ENTITY_ONLY => 1
            });
            if (ref $res ne 'ARRAY' || scalar @{$res} != 1) {
                $log->error("SOAP: RevokeCertificateByIssuerSerial - no certificate found: " .
                    "serial: " . $arg->{serial} . ", issuer: " . $arg->{issuer_dn});

                OpenXPKI::Exception->throw(
                    message => 'Unable to find a certificate for given issuer/serial',
                    params => { CERT_SERIAL => $arg->{serial}, ISSUER_DN   => $arg->{issuer_dn} }
                );
            }

            # Add original data to the crr info hash
            $crr_info->{serial} = $arg->{serial};
            $crr_info->{issuer_dn} = $arg->{issuer_dn};

            $arg->{cert_identifier} = $res->[0]->{IDENTIFIER};
            $log->debug('Found certificate ' . $arg->{cert_identifier});
        }

        $log->info("SOAP Revoke (uri: $canonical_uri, client ip=$client_ip, cert=".$arg->{cert_identifier}.", reason=" . $arg->{reason});

        my $serializer = OpenXPKI::Serialization::Simple->new();

        my %param = (
            cert_identifier => $arg->{cert_identifier},
            reason_code     => $arg->{reason},
            crr_info        => $serializer->serialize($crr_info),
            server          => $servername,
            interface       => 'soap',
            signer_cert     => $auth_pem,
            flag_batch_mode => 1,
            comment         => 'via soap',
            invalidity_time => 0,
        );

        $log->trace( "WF parameters: " . Dumper \%param );

        $workflow = $client->handle_workflow({
            TYPE => $workflow_type,
            PARAMS => \%param
        });

        $log->trace( 'Workflow info '  . Dumper $workflow );
    };

    my $res;
    if ( my $exc = OpenXPKI::Exception->caught() ) {
        $log->error("Unable to create workflow: ". $exc->message );
        $res = { error => $exc->message, pid => $$ };
    } elsif (my $eval_err = $EVAL_ERROR) {
        my $ee = $client->last_error();
        $log->error("Unable to create workflow: ". $eval_err );
        if ($ee) {
            $res = { error => $ee, pid => $$ };
        } else {
            $res = { error => 'Uncaught error while processing request', pid => $$ };
        }
    } elsif (!$workflow->{ID} || $workflow->{'PROC_STATE'} eq 'exception' || $workflow->{'STATE'} eq 'FAILURE') {
        $log->error("Workflow terminated in unexpected state" );
        $res = { error => 'workflow terminated in unexpected state', pid => $$, id => $workflow->{id}, 'state' => $workflow->{'STATE'} };
    } else {
        $log->info(sprintf("Revocation request was processed properly (Workflow: %01d, State: %s",
            $workflow->{ID}, $workflow->{STATE}) );
        $res = { error => '', id => $workflow->{ID}, 'state' => $workflow->{'STATE'} };
    }

    $client->disconnect();

    return SOAP::Data->new( name => 'result', value => $res );

}

# Keep the old method intact
sub RevokeCertificate{

    my $self = shift;

    $log->warn('SOAP: RevokeCertificate - deprecated method, use RevokeCertificateByIdentifier.');

    return $self->RevokeCertificateByIdentifier( @_ );

}

sub RevokeCertificateByIdentifier {

    my $self = shift;
    my $cert_identifier = shift;
    my $reason          = shift || 'unspecified';

    $log->debug(
        "SOAP: RevokeCertificate - ",
        "certificate: $cert_identifier, ",
        "reason: $reason"
    );

    if (!$cert_identifier) {
        return SOAP::Data->new( name => 'result', value => { error => 'parameter missing'} );
    }

    return $self->__dispatch_revoke({
        cert_identifier => $cert_identifier,
        reason => $reason
    });

}

sub RevokeCertificateByIssuerSerial {

    my $self       = shift;
    my $issuer_dn   = shift;
    my $serial      = shift;
    my $reason      = shift || 'unspecified';

    $log->debug(
        "SOAP: RevokeCertificateByIssuerSerial - ",
        "Issuer: $issuer_dn, ",
        "Serial: $serial, ",
        "reason: $reason"
    );

    if (!$issuer_dn || !$serial) {
        return SOAP::Data->new( name => 'result', value => { error => 'parameter missing' } );
    }

    return $self->__dispatch_revoke({
        issuer_dn => $issuer_dn,
        serial => $serial,
        reason => $reason
    });

}


sub true {
    my $self = shift;
    warn "Entered 'true'";
    return 1;
}

sub false {
    my $self = shift;
    return 0;
}

sub echo {
    my $self = shift;
    return shift @_;
}

1;
