# SOAP service implementing revocation interface for smartcard

use strict;
use warnings;

package OpenXPKI::SOAP::Smartcard;

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

# Adjust path to binary!
sub RevokeSmartcard {

    my $class           = shift;
    my $card_identifier = shift;
    my $jobid           = shift || '<not defined>';

    $log->debug(
        "SOAP: RevokeSmartcard - ",
        "CardId: $card_identifier, ",
        "RequestId: $jobid"
    );

    my $config = $main::config->config();

    my $client_ip   = $ENV{REMOTE_ADDR};    # dotted quad
    my $server_name = $ENV{SERVER_NAME};    # ca.company.com
    my $request_uri = $ENV{REQUEST_URI};    # "/soap/"

    my $canonical_uri = $server_name . $request_uri;

    $log->info("SOAP Revoke (uri: $canonical_uri, client ip=$client_ip, card=$card_identifier");

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
        $log->error("SOAP SmartcardRevoke: no workflow_type set for requested URI $canonical_uri");
        return SOAP::Data->new( name => 'responseCode', value => 1 );
    }

    my $workflow;
    eval {
        my $client = OpenXPKI::Client::Simple->new({
            logger => $log,
            config => $config->{global}, # realm and locale
            auth => $config->{auth}, # auth config
        });

        if ( !$client ) {
            $log->error("Could not instantiate client object");
            return SOAP::Data->new( name => 'responseCode', value => 1 );
        }

        my $serializer = OpenXPKI::Serialization::Simple->new();

        my %param = (
            token_id => $card_identifier,
            crr_info        => $serializer->serialize({
                requester_sn    => $auth_dn || '',    # default to empty string (must not be undef)
                client_ip       => $client_ip,
            }),
            server => $servername,
            interface => 'soap',
            signer_cert => $auth_pem
        );

        $log->trace( "WF parameters: " . Dumper \%param );

        $workflow = $client->handle_workflow({
            TYPE => $workflow_type,
            PARAMS => \%param
        });

        $log->trace( 'Workflow info '  . Dumper $workflow );
    };

    if ( my $exc = OpenXPKI::Exception->caught() ) {
        $log->error("Unable to create workflow: ". $exc->message );
        return SOAP::Data->new( name => 'responseCode', value => 1 );
    } elsif ($EVAL_ERROR) {
        $log->error("Unable to create workflow: ". $EVAL_ERROR );
        return SOAP::Data->new( name => 'responseCode', value => 1 );
    } elsif (!$workflow->{ID} || $workflow->{'PROC_STATE'} eq 'exception' || $workflow->{'STATE'} eq 'FAILURE') {
        $log->error("Workflow terminated in unexpected state " );
        return SOAP::Data->new( name => 'responseCode', value => 1 );
    }

    $log->info(sprintf("Revocation request was processed properly (Workflow: %01d, State: %s",
        $workflow->{ID}, $workflow->{STATE}) );

    return SOAP::Data->new( name => 'responseCode', value => 0 );
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
