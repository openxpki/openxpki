#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use CGI;
use CGI::Fast;
use Data::Dumper;
use JSON::PP;
use Scalar::Util qw( blessed );
use English;
use Encode;

# CPAN modules
use Crypt::JWT qw(decode_jwt);
use Log::Log4perl;
use Log::Log4perl::MDC;

# Project modules
use OpenXPKI::Exception;
use OpenXPKI::Client::Config;
use OpenXPKI::Client::Service::RPC;
use OpenXPKI::Client::Service::Response;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::i18n qw( i18nGettext i18n_walk );

# Feature::Compat::Try should be done last to safely disable warnings
use Feature::Compat::Try;


my $config;
my $log;

my $use_status_codes = 0;
my $json = JSON::PP->new->utf8;

# Use plain scalars as boolean values. The default representation as
# JSON::PP::Boolean would cause the values to be serialized later on.
# A JSON false would be converted to a trueish scalar "OXJSF1:false".
$json->boolean_values(0,1);

sub send_output {
    my ($cgi, $response, $canonical_keys) = @_;

    my $status = '200 OK';
    my %retry_head;

    if ($use_status_codes) {
        if ($response->has_error) {
            $status = $response->http_status_line;
        } elsif ($response->is_pending) {
            $status = '202 Request Pending - Retry Later';
            %retry_head = ("-retry-after" => $response->retry_after );
        }
    }

    if ($ENV{'HTTP_ACCEPT'} && $ENV{'HTTP_ACCEPT'} eq 'text/plain') {
        my $data = $response->has_result ? ($response->result->{data} // {}) : {};
        print $cgi->header( -type => 'text/plain', charset => 'utf8', -status => $status, %retry_head );
        if ($response->has_error) {
            print 'error.code=' . $response->error."\n";
            print 'error.message=' . $response->error_message."\n";

        } elsif ($response->has_result) {
            print 'id=' . $response->result->{id}."\n";
            print 'state=' . $response->result->{state}."\n";
            print 'retry_after=' . $response->retry_after ."\n" if $response->is_pending;
        }
        do { printf "data.%s=%s\n", $_, $data->{$_} for keys $data->%* };

    } else {
        print $cgi->header( -type => 'application/json', charset => 'utf8', -status => $status );
        $json->max_depth(20);
        $json->canonical( $canonical_keys ? 1 : 0 );

        # run i18n tokenzier on output if a language is set
        print $json->encode( $config->language ? i18n_walk($response->result) : $response->result );
    }
}

try {
    $config = OpenXPKI::Client::Config->new('rpc');
    $log = $config->logger;
}
catch ($error) {
    my $cgi = CGI::Fast->new();
    print $cgi->header( -type => 'application/json', charset => 'utf8', -status => '500 Client Connect Failed' );
    print $json->encode( { error => { code => 50001, message => $OpenXPKI::Client::Service::Response::named_messages{50001} } } );
    die "Client Connect Failed: $error";
}

$log->info("RPC handler initialized");

my $client;

CGI_LOOP:
while (my $cgi = CGI::Fast->new("")) {

    my $req = OpenXPKI::Client::Service::RPC->cgi_to_mojo_request;

    my $backend;

    try {
        my $ep_config;
        my ($endpoint, $route);
        try {
            ($endpoint, $route) = $config->parse_uri;
            $ep_config = $config->endpoint_config($endpoint);
        }
        catch ($error) {
            $log->error($error);
            die OpenXPKI::Client::Service::Response->new_error( 50007 );
        }

        $client = OpenXPKI::Client::Service::RPC->new(
            config_obj => $config,
            apache_env => \%ENV,
            remote_address => $ENV{REMOTE_ADDR},
            request => $req,
            endpoint => $endpoint,
        );

        $use_status_codes = $ep_config->{output} && $ep_config->{output}->{use_http_status_codes};

        # check for request parameters in JSON data (HTTP body)
        my $operation = $client->query_params->param('method');

        if (my $raw = $client->request->body) {

            $client->failure( 40083 ) unless $ep_config->{input}->{allow_raw_post};

            my $content_type = $ENV{'CONTENT_TYPE'} || '';
            if (!$content_type) {
                $content_type =~ 'application/json';
                $log->warn("RPC POSTDATA request without content-type header");
            }

            $log->debug("RPC postdata with Content-Type: $content_type");

            # TODO - evaluate security implications regarding blessed objects
            # and consider to filter out serialized objects for security reasons
            $json->max_depth(  $ep_config->{input}->{parse_depth} || 5 );

            if ($content_type =~ m{\Aapplication/jose}) {

                $client->failure( 40087 ) unless $ep_config->{jose};

                # The cert_identifier used to sign the token must be set as kid
                # First run - set ignore_signature to just get the header with the kid
                my ($cert_identifier, $cert);
                my ($jwt_header, undef) = decode_jwt(token => $raw, ignore_signature => 1, decode_header => 1, decode_payload => 0);

                if ($jwt_header->{alg} !~ m{\A(R|E)S256\z}) {
                    $client->failure( 40090, { alg => $jwt_header->{alg} } );
                }

                $client->jwt_header($jwt_header);

                # we currently only support "known" certificates as signers
                # the recommended way is to use the x5t header field
                if ($jwt_header->{x5t}) {
                    $cert_identifier = $jwt_header->{x5t};
                    $log->debug("JWT header has x5t set to $cert_identifier");
                # as a fallback we support passing the identifier in the kid field
                # to allow adding other key patterns later we use a namespace
                } elsif (substr(($jwt_header->{kid}//''), 0, 6) eq 'certid') {
                    $cert_identifier = substr($jwt_header->{kid}, 7);
                    $log->debug("JWT header has kid set to $cert_identifier");
                } else {
                    $client->failure( 40088, "No key id was found in the JWT header" );
                }

                # to prevent nasty attacks we require that the method name is part of the protected header
                $operation = $jwt_header->{method} || $client->failure( 40089 );

                $backend = $client->backend();
                try {
                    # this will die if the certificate was not found
                    # TOOD - this call fails if no backend connection can be made which gives a misleading
                    # error code to the customer - this can also happen on a misconfigured auth stack :)
                    # might also be useful to have a validated "certificate" used for the session login
                    # so the likely best option would be some kind on "anonymous" client here
                    # See #903 and #904 on github
                    $cert = $backend->run_command('get_cert', { identifier => $cert_identifier, format => 'PEM' });

                    # use our json parser object to decode to limit parsing depth
                    $raw = decode_jwt(token => $raw, key => \$cert, decode_payload => 0);
                    $log->trace("Encoded JSON postdata: $raw") if $log->is_trace;

                    $jwt_header->{signer_cert} = $cert;
                }
                catch ($err) {
                    $client->failure( 40088, $cert ? 'JWT signature could not be verified' : 'Given key id was not found' );
                }

                $client->jwt_header($jwt_header);

            } elsif ($content_type =~ m{\Aapplication/pkcs7}) {

                $client->failure( 40091 ) unless $ep_config->{pkcs7};

                $client->pkcs7($raw);
                $backend = $client->backend;
                try {
                    my $pkcs7_content = $backend->run_command('unwrap_pkcs7_signed_data', {
                        pkcs7 => $client->pkcs7,
                    });
                    $client->pkcs7_content($pkcs7_content);
                    $log->trace("PKCS7 content: " . Dumper $pkcs7_content) if $log->is_trace;
                    $raw = $pkcs7_content->{value} or $client->failure( 50080 );
                }
                catch ($error) {
                    $client->failure( 50080, $error );
                }

                $log->trace("PKCS7 payload: " . $raw) if $log->is_trace;

            } elsif ($content_type =~ m{\Aapplication/json}) {

                $log->trace("Encoded JSON postdata: " . $raw) if $log->is_trace;

            } else {

                $client->failure( 40084, { type => $content_type } );
            }

            # decode JSON
            $client->failure( 40081 ) unless $raw;

            try {
                my $json_data = $json->decode($raw);
                $client->json_data($json_data);
                # read operation from JSON data if not found in URL before
                $operation ||= $json_data->{method};
            }
            catch ($error) {
                $log->error($error);
                $client->failure( 40081 );
            }
        }

        $operation ||= $route;

        # method should be set now
        $client->failure( 40080 ) unless $operation;

        # special handling for requests for OpenAPI (Swagger) spec
        if ($operation eq 'openapi-spec') {
            my $url = $client->request->url->to_abs;
            my $baseurl = sprintf "%s://%s%s", $url->protocol, $url->host_port, $url->path->to_abs_string;
            my $spec = $client->openapi_spec($baseurl) or $client->failure( 50082 );
            send_output($cgi, OpenXPKI::Client::Service::Response->new(result => $spec), 1);
            next CGI_LOOP;
        }

        $client->operation($operation);

        # "workflow" is required even though with "execute_action" we don't need it.
        # But the check here serves as a config validator so that a correct OpenAPI
        # Spec will be generated upon request.
        my $workflow_type = $ep_config->{$operation}->{workflow};
        $client->failure( 40480, "RPC method $operation not found or no workflow_type set" )
          unless defined $workflow_type;

        $log->trace( "Calling '$operation' on '$endpoint' with parameters: " . Dumper $client->wf_params ) if $log->is_trace;

        my $workflow;

        try {
            # create the client object
            $backend = $client->backend;

            # check for pickup parameter
            if (my $pickup_key = $ep_config->{$operation}->{pickup}) {
                my $pickup_value;
                # "pickup_workflow" needs a parameter HashRef
                if ($ep_config->{$operation}->{pickup_workflow}) {
                    my @keys = split /\s*,\s*/, $pickup_key;
                    foreach my $key (@keys) {
                        # take value from param hash if defined, this makes data
                        # from the environment available to the pickup workflow
                        my $val = $client->wf_params->{$key} // $client->get_param($key);
                        $pickup_value->{$key} = $val if defined $val;
                    }
                # "pickup_namespace" and "pickup_attribute" need a single value - see pickup_workflow()
                } else {
                    $pickup_value = $client->get_param($pickup_key);
                }
                if ($pickup_value) {
                    $workflow = $client->pickup_workflow($ep_config->{$operation}, $pickup_value);
                } else {
                    $log->trace("Ignoring workflow pickup because '$pickup_key' has no value") if $log->is_trace;
                }
            }

            # Endpoint has a "resume and execute" definition so run action if possible
            #
            # If "execute_action" is defined it enforces "pickup_workflow" and we never
            # start a new workflow, even if no "pickup" parameters were given.
            if (my $execute_action = $ep_config->{$operation}->{execute_action}) {
                if (!$workflow) {
                    $client->failure( 40481 );

                } elsif ($workflow->{'proc_state'} ne 'manual') {
                    $client->failure( 40482, { id => $workflow->{id}, 'state' => $workflow->{'state'}, proc_state => $workflow->{'proc_state'} } );

                } else {
                    my $actions_avail = $backend->run_command('get_workflow_activities', { id => $workflow->{id} });
                    if (!(grep { $_ eq  $execute_action } @{$actions_avail})) {
                        $client->failure( 40483, { id => $workflow->{id}, 'state' => $workflow->{'state'}, proc_state => $workflow->{'proc_state'} } );
                    } else {
                        $log->debug("Resume #".$workflow->{id}." and execute '$execute_action' with params: " . join(", ", keys $client->wf_params->%*));
                        $workflow = $backend->handle_workflow({
                            id => $workflow->{id},
                            activity => $execute_action,
                            params => $client->wf_params,
                        });
                    }
                }

            # pickup return undef if no workflow was found
            } elsif (not $workflow) {
                $log->debug("Initialize '$workflow_type' with params: " . join(", ", keys $client->wf_params->%*));
                $workflow = $backend->handle_workflow({
                    type => $workflow_type,
                    params => $client->wf_params,
                });
            }

            $log->trace( 'Workflow info '  . Dumper $workflow ) if $log->is_trace;
        }
        catch ($err) {
            #
            # Special internal error hash generated by failure() - rethrow
            #
            if (ref $err eq 'HASH' and $err->{rpc_failure}) {
                die $err;
            }

            #
            # OpenXPKI::Exception - convert into special internal error hash
            #
            if (blessed $err) {
                $client->failure(40101, $err->message) if $err->isa('OpenXPKI::Exception::Authentication');
                $client->failure(50000, $err->message) if $err->isa('OpenXPKI::Exception');
            }

            #
            # Validation error
            #
            my $reply = $backend->last_reply();
            # TODO this needs to be reworked
            if ($reply->{ERROR}
                && ($reply->{ERROR}->{CLASS}//'') eq 'OpenXPKI::Exception::InputValidator'
                && $reply->{ERROR}->{ERRORS}
            ) {
                $log->trace(Dumper $reply);
                my $error = join ", ", map { $_->{name} }  @{$reply->{ERROR}->{ERRORS}};
                $client->failure( 40082, $error || $reply->{ERROR}->{LABEL} || '', { fields => $reply->{ERROR}->{ERRORS} } );

            } else {
                my $error;
                my $error_code = 50000;
                if ($reply->{ERROR} && $reply->{ERROR}->{LABEL}) {
                    $error = $reply->{ERROR}->{LABEL};
                }
                else {
                    $error = $backend->last_error;
                    if (not $error) {
                        if (blessed $err and $err->isa('OpenXPKI::Client::Service::Response')) {
                            $error = $err->error_message;
                            $error_code = $err->error;
                        } else {
                            $error = $err;
                            $error_code = 40000;
                        }
                    }
                }
                $log->error($error);
                my $msg_public = (($error//'') =~ /I18N_OPENXPKI_UI_/) ? $error : 'internal error';
                $client->failure( $error_code, $msg_public );
            }
        }

        my $response = OpenXPKI::Client::Service::Response->new;
        my $res;

        # no ID and not finished is an unrecoverable startup error
        if (( $workflow->{'proc_state'} ne 'finished' && !$workflow->{id} ) || $workflow->{'proc_state'} eq 'exception') {

            $client->failure( 50081, { id => $workflow->{id}, 'state' => $workflow->{'state'} } );

        # if the workflow is running, we do not expose any data of the workflows
        } elsif ( $workflow->{'proc_state'} eq 'running' ) {

            $log->info(sprintf("RPC request was processed properly (Workflow: %s is currently running)",
                $workflow->{id} ));
            $res = { result => { id => $workflow->{id}, 'state' => '--', 'proc_state' => $workflow->{'proc_state'}, pid => $$ }};

        } else {

            $log->info(sprintf("RPC request was processed properly (Workflow: %s, State: %s (%s))",
                $workflow->{id}, $workflow->{state}, $workflow->{'proc_state'}) );
            $res = { result => { id => $workflow->{id}, 'state' => $workflow->{'state'}, 'proc_state' => $workflow->{'proc_state'}, pid => $$ }};

            # if pickup is set and workflow is not in a final state we send a 202
            if ($ep_config->{$operation}->{pickup}) {
                if ($workflow->{'proc_state'} eq 'pause') {
                    my $delay = $workflow->{'wake_up_at'} - time();
                    $response->retry_after($delay > 30 ? $delay : 30);
                    $log->debug("Need retry - workflow is paused - delay $delay");
                } elsif ($workflow->{'proc_state'} ne 'finished') {
                    $response->retry_after(300);
                    $log->debug("Need retry - workflow is " . $workflow->{'proc_state'});
                }
            }

            # Map context parameters to the response if requested
            if ($ep_config->{$operation}->{output}) {
                $res->{result}->{data} = {};
                my @keys;
                @keys = split /\s*,\s*/, $ep_config->{$operation}->{output};
                $log->debug("Keys " . join(", ", @keys));
                $log->trace("Raw context: ". Dumper $workflow->{context}) if $log->is_trace;
                foreach my $key (@keys) {
                    my $val = $workflow->{context}->{$key};
                    next unless (defined $val);
                    next unless ($val ne '' || ref $val);
                    if (OpenXPKI::Serialization::Simple::is_serialized($val)) {
                        $val = OpenXPKI::Serialization::Simple->new->deserialize( $val );
                    }
                    $res->{result}->{data}->{$key} = $val;
                }
            }
        }

        $response->result($res);
        send_output( $cgi, $response );
    }
    catch ($err) {
        # special internal error hash generated by failure()
        if (blessed $err and $err->isa('OpenXPKI::Client::Service::Response')) {
            send_output( $cgi, $err );
        }
        # unknown error
        else {
            $log->error($err) if $log;
            send_output( $cgi, OpenXPKI::Client::Service::Response->new_error(400) );
        }
    }
    finally {
        $client->disconnect_backend if $client;
    }
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
