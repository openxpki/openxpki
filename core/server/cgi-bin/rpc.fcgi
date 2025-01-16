#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use CGI;
use CGI::Fast;
use JSON::PP;
use English;
use Encode;

# CPAN modules
use Log::Log4perl;
use Log::Log4perl::MDC;

# Project modules
use OpenXPKI::Exception;
use OpenXPKI::Client::Config;
use OpenXPKI::Client::Service::RPC;
use OpenXPKI::Client::Service::Response;
use OpenXPKI::i18n qw( i18n_walk );

# Feature::Compat::Try should be done last to safely disable warnings
use Feature::Compat::Try;


my $config;
my $log;
my $openapi_mode;

my $json = JSON::PP->new->utf8;
# Use plain scalars as boolean values. The default representation as
# JSON::PP::Boolean would cause the values to be serialized later on.
# A JSON false would be converted to a trueish scalar "OXJSF1:false".
$json->boolean_values(0,1);

sub send_output {
    my ($cgi, $response, $use_status_codes) = @_;

    my $status = '200 OK';
    my %retry_head;

    if ($use_status_codes) {
        if ($response->has_error) {
            $status = $response->http_status_line;
            chomp $status;
        } elsif ($response->is_pending) {
            $status = '202 Request Pending - Retry Later';
            %retry_head = ("-retry-after" => $response->retry_after );
        }
    }

    if ($ENV{'HTTP_ACCEPT'} && $ENV{'HTTP_ACCEPT'} eq 'text/plain') {
        print $cgi->header( -type => 'text/plain', charset => 'utf8', -status => $status, %retry_head );
        if ($response->has_error) {
            printf "error.code=%s\n", $response->error;
            printf "error.message=%s\n", $response->error_message;
            printf "data.%s=%s\n", $_, $response->error_details->{$_} for keys $response->error_details->%*;

        } elsif ($response->has_result) {
            printf "id=%s\n", $response->result->{id};
            printf "state=%s\n", $response->result->{state};
            printf "retry_after=%s\n", $response->retry_after if $response->is_pending;

            my $data = $response->has_result ? ($response->result->{data} // {}) : {};
            printf "data.%s=%s\n", $_, $data->{$_} for keys $data->%*;
        }

    } else {
        print $cgi->header( -type => 'application/json', charset => 'utf8', -status => $status );
        $json->max_depth(20);
        $json->canonical( $openapi_mode ? 1 : 0 );

        if ($response->has_error) {
            print $json->encode({
                error => {
                    code => $response->error,
                    message => $response->error_message,
                    $response->has_error_details ? (data => $response->error_details) : (),
                }
            });
        } else {
            # run i18n tokenzier on output if a language is set
            my $data = $config->language ? i18n_walk($response->result) : $response->result;
            if ($openapi_mode) {
                print $json->encode($data);
            } else {
                print $json->encode({
                    result => {
                        $data->%*,
                        $response->is_pending ? (retry_after => $response->retry_after) : (),
                    }
                });
            }
        }

    }
}

$config = OpenXPKI::Client::Config->new('rpc');
$log = $config->log;
$log->info("RPC handler initialized");

while (my $cgi = CGI::Fast->new("")) {
    $openapi_mode = 0;

    my $req = OpenXPKI::Client::Service::RPC->cgi_to_mojo_request;

    my $ep_config;
    my ($endpoint, $route);
    try {
        ($endpoint, $route) = $config->parse_uri;
        $ep_config = $config->endpoint_config($endpoint);
    }
    catch ($error) {
        $log->error($error);
        send_output($cgi, OpenXPKI::Client::Service::Response->new( 50007 ), 0);
        next;
    }

    my $client = OpenXPKI::Client::Service::RPC->new(
        service_name => 'rpc',
        config_obj => $config,
        webserver_env => \%ENV,
        remote_address => $ENV{REMOTE_ADDR},
        request => $req,
        endpoint => $endpoint,
        take_pickup_value_from_request => 1,
    );

    my $response = cgi_safe_sub $client, sub {
        $client->try_set_operation($client->request_param('method'));
        $client->parse_rpc_request_body;
        $client->try_set_operation($route);
        die $client->new_response( 40080 ) unless $client->has_operation;

        # special handling for requests for OpenAPI (Swagger) spec
        if ($client->operation eq 'openapi-spec') {
            my $url = $client->request->url->to_abs;
            my $baseurl = sprintf "%s://%s%s", $url->protocol, $url->host_port, $url->path->to_abs_string;
            my $spec = $client->openapi_spec($baseurl) or die $client->new_response( 50082 );
            $openapi_mode = 1;
            return OpenXPKI::Client::Service::Response->new(result => $spec);
        }

        return $client->handle_rpc_request;
    };

    send_output( $cgi, $response, $client->use_status_codes );

    $client->disconnect_backend;
}

1;

__END__;

=head1 rpc.fcgi

A RPC interface to run workflows

=head1 Configuration

The wrapper uses the OpenXPKI::Client::Config module to load a config
file based on the called script name.

=head2 Basic Configuration

The basic configuration in default.conf must contain log and auth info:

  [global]
  log_config = /etc/openxpki/rpc/log.conf
  log_facility = client.rpc
  socket = /var/openxpki/openxpki.socket

  [auth]
  stack = _System
  pki_realm = democa

=head2 Method Invocation

The parameters are expected in the query string or in the body of a
HTTP POST operation (application/x-www-form-urlencoded). A minimal
request must provide the parameter "method". The name of the used method
must match a section in the config file. The section must at least contain
the name of a workflow:

  [RevokeCertificateByIdentifier]
  workflow = status_system

You need to define parameters what parameters should be mapped from the
input to the workflow. Values for the given keys are copied to the
workflow input parameter with the same name. In addition, you can load
certain information from the environment

  [RevokeCertificateByIdentifier]
  workflow = certificate_revocation_request_v2
  param = cert_identifier, reason_code, comment, invalidity_time
  env = signer_cert, signer_chain, signer_dn, client_ip, server, endpoint

The keys I<server> and I<endpoint> fill the parameters with the same name
with the autodetected value from the URI path.

The keys I<signer_cert/signer_dn> are available on authenticated TLS
connections or when using raw PKCS7 payloads. They are filled with the PEM
block and the full subject dn of the authentication/signature certificate.

For TLS connections, I<signer_chain> will also pass the chain certificates
send by the client to the workflow. TLS properties are also available via
I<tls_client_cert/tls_client_chain/tls_client_dn>. If you use PKCS7 and TLS
in parallel the I<signer_*> keys will point to the PKCS7 based data while
those will always show data from the TLS client authentication.

Note that you must set ExportCertData and StdEnvVars option in apache to
make those keys available for TLS connections!

If the workflow uses endpoint specific configuraton, you must also set the
name of the server using the I<servername> key. This is mutually exclusive
with env=server.

  [RevokeCertificateByIdentifier]
  workflow = certificate_revocation_request_v2
  param = cert_identifier, reason_code, comment, invalidity_time
  env = signer_cert, signer_dn, client_ip
  servername  = myserver

=head2 Response

=head3 Success

The default response does not include any data from the workflow itself,
it just returns the meta information of workflow:

  {"result":{"id":"300287","pid":4375,"state":"SUCCESS"}}';

I<id> is the workflow id, which can be used in the workflow search to
access this workflow, I<state> is the current state of the workflow.
I<pid> is the internal process id and only relevant for extended debug.

Note: A successfull RPC response does not tell you anything about the
status of the requested business process! It just says that the workflow
ran in a technical expected manner.

=head3 Process Information

You can add a list of workflow context items to be exported with the
response:

    [RequestCertificate]
    workflow = certificate_enroll
    param = pkcs10, comment
    output = cert_identifier, error_code

This will add a new section I<data> to the response with the value of the
named context item. Items are only included if they exist.

    {"result":{"id":"300287","pid":4375,"state":"SUCCESS",
        "data":{"cert_identifier":"i7Dvxp7fz_9WZlzf9hW_9tlbF6M"},
    }}

=head3 Error Response

In case the workflow can not be created or terminates with an unexpected
error, the return structure looks different:

 {"error":{"data":{"pid":4567,"id":12345},"code":42,
     "message":"I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_CREATE_PERMISSION_DENIED"
 }}

The message gives a verbose description on what happend, the data node will
contain the workflow id only in case it was started.

Error code in the range 4xx indicate a client error, 5xx a problem on the
server (which might also be related to on inappropriate input data).

=over

=item 40080 - no method in request

No method name could be found in the request.

=item 40081 - decoding of JSON encoded POST data failed

Data send as JSON POST could not be parsed. The reason is either malformed
JSON structure or the data has nested structures exceeding the parse_depth.

=item 40082 - wrong input values

The given parameters do not pass the input validation rules of the workflow.
You will find the verbose error in I<message> and the list of affected fields
in the I<fields> key.

=item 40083 - RAW Post not allowed

RAW post was detected but is not allowed by configuration.

=item 40084 - RAW Post with unknown Content-Type

The Content-Type set with a RAW post request is not known.
Supported types are application/json and application/pkcs7.

=item 40480 - Invalid method / setup incomplete

The method name given is either not defined or has no workflow defined

=item 40481 - Resume requested but nothing to pickup

The method name has an execute statement but no workflow to be continued
was found using the given pickup rules

=item 40482 - Resume requested but workflow is not in manual state

The method name has an execute statement but the loaded workflow is
not in a state that accepts external input

=item 40483 - Resume requested but expected method is not available

The method name has an execute statement but the expected activity is
not available in the loaded workflow

=item 50000 - Server exception

The server ran into an exception while handling the request, details might
be found in the error message.

=item 50002 - Error initializing client

The webserver was unable to setup the client side. Details can be found
in the error message. Common reason is that the server is too busy or not
running and unable to handle the request at all.

=item 50081 - workflow error

The request was handled by the server properly but the workflow has
encountered an unexpected state.

=item 50080 - error getting OpenAPI spec

The openapi-spec could not be loaded. Usually this means that not all
parameters are defined in the expeced format.

=item 50005 - inconsistent configuration

An explicit servername was set while env=server is also set.

=item 50006 - no endpoint name for env=server

The script path could not be parsed for an endpoint name but env=server
is requested.

=back

=head2 TLS Authentication

In case you want to use TLS Client authentication you must tell the
webserver to pass the client certificate to the script. For apache,
put the following lines into your SSL Host section:

    <Location /rpc>
        SSLVerifyClient optional
        SSLOptions +StdEnvVars +ExportCertData
    </Location>
