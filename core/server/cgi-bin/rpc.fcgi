#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Fast;
use Data::Dumper;
use English;

use JSON;
use MIME::Base64;
use OpenXPKI::Exception;
use OpenXPKI::Client::Simple;
use OpenXPKI::Client::Config;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::i18n qw( i18nGettext );

use Log::Log4perl;
use Log::Log4perl::MDC;

our $config = OpenXPKI::Client::Config->new('rpc');
my $log = $config->logger();

$log->info("RPC handler initialized");

my $json = new JSON();
my $use_status_codes = 0;

sub send_output {
    my ($cgi, $result, $canonical_keys) = @_;

    my $status = '200 OK';

    if (defined $result->{error}) {
        if ($result->{error}->{message} && $result->{error}->{message} =~ m{I18N_OPENXPKI_UI}) {
            $result->{error}->{message} = i18nGettext($result->{error}->{message});
        }
        if ($use_status_codes) {
            my ($error) = split(/[:\n]/, $result->{error}->{message});
            $status = sprintf ("%03d %s", ($result->{error}->{code}/100), $error);
        }
    }

    if ($ENV{'HTTP_ACCEPT'} && $ENV{'HTTP_ACCEPT'} eq 'text/plain') {
       print $cgi->header( -type => 'text/plain', charset => 'utf8', -status => $status );
       if ($result->{error}) {
           print 'error.code=' . $result->{error}->{code}."\n";
           print 'error.message=' . $result->{error}->{message}."\n";
       } else {
           print 'id=' . $result->{result}->{id}."\n";
           print 'state=' . $result->{result}->{state}."\n";
           map { printf "data.%s=%s\n", $_, $result->{result}->{data}->{$_} } keys %{$result->{result}->{data}} if ($result->{result}->{data});
       }

    } else {
        # prepare response header
        print $cgi->header( -type => 'application/json', charset => 'utf8', -status => $status );
        $json->max_depth(20);
        $json->canonical(1) if $canonical_keys;
        print $json->encode( $result );
    }

}

sub _create_client {
    my ($cgi, $conf) = @_;

    my $client = OpenXPKI::Client::Simple->new({
        logger => $log,
        config => $conf->{global}, # realm and locale
        auth => $conf->{auth}, # auth config
    });

    if ( !$client ) {
        # TODO: Return as "500 Internal Server Error"?
        $log->error("Could not instantiate client object");
        send_output( $cgi,  { error => {
            code => 50001,
            message=> "Could not instantiate client object",
            data => { pid => $$ }
        }});
        return;
    }

    return $client;
}

sub _openapi_spec {
    my ($cgi, $conf) = @_;

    my $openapi_server_url = sprintf "%s://%s:%s%s", ($cgi->https ? 'https' : 'http'), $cgi->virtual_host, $cgi->virtual_port, $cgi->request_uri;

    my $openapi_spec = {
        openapi => "3.0.0",
        info => { title => "OpenXPKI RPC API", version => "0.0.1", description => "Run a defined set of OpenXPKI workflows" },
        servers => [ { url => $openapi_server_url, description => "OpenXPKI server" } ],
        components => {
            schemas => {
                Error => {
                    type => 'object',
                    properties => {
                        'error' => {
                            type => 'object',
                            description => 'Only set if an error occured while executing the command',
                            required => [qw( code message data )],
                            properties => {
                                'code' => { type => 'integer', },
                                'message' => { type => 'string', },
                                'data' => {
                                    type => 'object',
                                    properties => {
                                        'pid' => { type => 'integer', },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    };

    my $paths;
    eval {
        my $client = _create_client($cgi, $conf) or die "Could not create OpenXPKI client";

        for my $method (sort keys %$conf) {
            next unless ($conf->{$method}->{workflow});
            my $in = $conf->{$method}->{param} || '';
            my $out = $conf->{$method}->{output} || '';
            my $method_spec = $client->run_command('get_rpc_openapi_spec', {
                workflow => $conf->{$method}->{workflow},
                input => [ split /\s*,\s*/, $in ],
                output => [ split /\s*,\s*/, $out ]
            });

            $paths->{"/$method"} = {
                post => {
                    description => $method_spec->{description},
                    requestBody => {
                        required => JSON::true,
                        content => {
                            'application/json' => {
                                schema => $method_spec->{input_schema},
                            },
                        },
                    },
                    responses => {
                        '200' => {
                            description => "JSON object with details either about the command result or the error",
                            content => {
                                'application/json' => {
                                    schema => {
                                        oneOf => [
                                            {
                                                type => 'object',
                                                properties => {
                                                    'result' => {
                                                        type => 'object',
                                                        description => 'Only set if command was successfully executed',
                                                        required => [qw( data state pid id )],
                                                        properties => {
                                                            'data' => $method_spec->{output_schema},
                                                            'state' => { type => 'string' },
                                                            'proc_state' => { type => 'string' },
                                                            'pid' => { type => 'integer', },
                                                            'id' => { type => 'integer', },
                                                        },
                                                    },
                                                },
                                            },
                                            {
                                                '$ref' => '#/components/schemas/Error',
                                            },
                                        ],
                                    },
                                },
                            },
                        },
                    },
                },
            };
        }

        $client->disconnect();
    };
    if (my $eval_err = $EVAL_ERROR) {
        # TODO: Return as "500 Internal Server Error"?
        $log->error("Unable to query OpenAPI specification from OpenXPKI server: $eval_err");
        send_output($cgi, { error => { code => 50004, message => $eval_err, data => { pid => $$ } } });
        return;
    }

    $openapi_spec->{paths} = $paths;

    return $openapi_spec;
}

while (my $cgi = CGI::Fast->new()) {

    my $conf = $config->config();

    my $method = $cgi->param('method');

    $use_status_codes = $conf->{output} && $conf->{output}->{use_http_status_codes};

    # check for request parameters in JSON data (HTTP body)
    my $postdata;
    if ($conf->{input}->{allow_raw_post} && $cgi->param('POSTDATA')) {
        # TODO - evaluate security implications regarding blessed objects
        # and consider to filter out serialized objects for security reasons
        $json->max_depth(  $conf->{input}->{parse_depth} || 5 );
        my $raw = $cgi->param('POSTDATA');
        $log->trace("RPC raw postdata : " . $raw) if ($log->is_trace());
        eval{$postdata = $json->decode($raw);};
        if (!$postdata || $EVAL_ERROR) {
            $log->error("RPC decoding postdata failed: " . $EVAL_ERROR);
            send_output( $cgi,  { error => {
                code => 40002,
                message=> "RPC decoding postdata failed",
                data => { pid => $$ }
            }});
            next;
        }
        # read "method" from JSON data if not found in URL before
        $method = $postdata->{method} unless $method;
    }

    $method = $config->route() unless($method);

    # method should be set now
    if ( !$method ) {
        # TODO: Return as "400 Bad Request"?
        $log->error("RPC no method set in request");
        send_output( $cgi,  { error => {
            code => 40001,
            message=> "RPC no method set in request",
            data => { pid => $$ }
        }});
        next;
    }

    # special handling for requests for OpenAPI (Swagger) spec?
    if ($method eq 'openapi-spec') {
        my $spec = _openapi_spec($cgi, $conf) or next;
        send_output($cgi, $spec, 1);
        next;
    }

    my $servername = $conf->{$method}->{servername} || '';

    Log::Log4perl::MDC->put('server', $servername);
    Log::Log4perl::MDC->put('endpoint', $config->endpoint());

    my $error = '';


    my $workflow_type = $conf->{$method}->{workflow};
    if ( !defined $workflow_type ) {
        # TODO: Return as "400 Bad Request"?
        $log->error("RPC no workflow_type set for requested method $method");
        send_output( $cgi,  { error => {
            code => 40401,
            message=> "RPC method $method not found or no workflow_type set",
            data => { pid => $$ }
        }});
        next;
    }

    # Only parameters which are whitelisted in the config are mapped!
    # This is crucial to prevent injection of server-only parameters
    # like the autoapprove flag...
    my $param;

    if ($conf->{$method}->{param}) {
        my @keys;
        @keys = split /\s*,\s*/, $conf->{$method}->{param};
        foreach my $key (@keys) {

            my $val;
            if ($postdata) {
                $val = $postdata->{$key};
            } else {
                $val = $cgi->param($key);
            }
            next unless (defined $val);

            if (!ref $val) {
                $val =~ s/\A\s+//;
                $val =~ s/\s+\z//;
            }
            $param->{$key} = $val;
        }
    }

    # if given, append to the paramter list
    if ($servername) {
        $param->{'server'} = $servername;
        $param->{'interface'} = 'rpc';
    }

    my %envkeys;
    if ($conf->{$method}->{env}) {
        %envkeys = map {$_ => 1} (split /\s*,\s*/, $conf->{$method}->{env});
    }

    # IP Transport
    if ($envkeys{'client_ip'}) {
        $param->{'client_ip'} = $ENV{REMOTE_ADDR};
    }

    if ($envkeys{'endpoint'}) {
        $param->{'endpoint'} = $config->endpoint();
    }

    # Gather data from TLS session
    my $auth_dn = '';
    my $auth_pem = '';
    if ( defined $ENV{HTTPS} && lc( $ENV{HTTPS} ) eq 'on' ) {

        $log->debug("calling context is https");
        $auth_dn = $ENV{SSL_CLIENT_S_DN};
        $auth_pem = $ENV{SSL_CLIENT_CERT};
        if ( defined $auth_dn ) {
            $log->info("RPC authenticated client DN: $auth_dn");

            if ($envkeys{'signer_dn'}) {
                $param->{'signer_cert'} = $auth_dn;
            }
            if ($auth_pem && $envkeys{'signer_cert'}) {
                $param->{'signer_cert'} = $auth_pem;
            }
        }
        else {
            $log->debug("RPC unauthenticated (no cert)");
        }
    } else {
        $log->debug("RPC unauthenticated (plain http)");
    }

    $log->trace( "Calling $method on ".$config->endpoint()." with parameters: " . Dumper $param ) if $log->is_trace;

    my $workflow;
    my $client;
    eval {

        # create the client object
        $client = _create_client($cgi, $conf) or next;

        my $wf_id;
        # check for pickup parameter
        if ($conf->{$method}->{pickup}) {
            my $pickup_key = $conf->{$method}->{pickup};
            my $pickup_value;
            if ($postdata) {
                $pickup_value = $postdata->{$pickup_key};
            } else {
                $pickup_value = $cgi->param($pickup_key);
            }

            if ($pickup_value) {
                $log->debug("Pickup workflow with $pickup_key => $pickup_value" );
                my $wfl = $client->run_command('search_workflow_instances', {
                    type => $workflow_type,
                    attribute => { $pickup_key => $pickup_value },
                    limit => 2
                });

                if (@$wfl > 1) {
                    die "Unable to pickup workflow - ambigous search result";
                } elsif (@$wfl == 1) {
                    $wf_id = $wfl->[0]->{workflow_id};
                    $log->debug("Pickup $wf_id by $pickup_key = $pickup_value");
                }
            }
        }

        if ($wf_id) {
            $workflow = $client->handle_workflow({
                type => $workflow_type,
                id => $wf_id
            });
        } else {
            $log->debug("Initialize with params " . join(", ", keys %{$param}));
            $workflow = $client->handle_workflow({
                type => $workflow_type,
                params => $param
            });
        }

        $log->trace( 'Workflow info '  . Dumper $workflow );
    };

    my $res;
    if ( my $exc = OpenXPKI::Exception->caught() ) {

        # TODO: Return as "500 Internal Server Error"?
        $log->error("Unable to instantiate workflow: ". $exc->message );
        $res = { error => { code => 50002, message => $exc->message, data => { pid => $$ } } };
    }
    elsif (my $eval_err = $EVAL_ERROR) {

        # TODO: Return as "500 Internal Server Error"?

        my $reply = $client->last_reply();
        $log->error(Dumper $reply);

        # Validation error
        my $error = $client->last_error() || $eval_err;

        # TODO this needs to be reworked
        if ($reply->{LIST}->[0]->{LABEL}
            eq 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATION_FAILED_ON_EXECUTE' &&
            $reply->{LIST}->[0]->{PARAMS}->{__FIELDS__}) {
            $res = { error => {
                code => 40003,
                message => $error,
                fields => $reply->{LIST}->[0]->{PARAMS}->{__FIELDS__},
                data => { pid => $$ }
            } };

        } else {
            $log->error("Unable to create workflow: ". $error );
            if (!$error || $error !~ /I18N_OPENXPKI_UI_/) {
                $error = 'uncaught error';
            }
            $res = { error => { code => 50002, message => $error, data => { pid => $$ } } };
        }

    } elsif (( $workflow->{'proc_state'} ne 'finished' && !$workflow->{id} ) || $workflow->{'proc_state'} eq 'exception') {

        # TODO: Return as "500 Internal Server Error"?
        $log->error("workflow terminated in unexpected state" );
        $res = { error => { code => 50003, message => 'workflow terminated in unexpected state',
            data => { pid => $$, id => $workflow->{id}, 'state' => $workflow->{'state'} } } };

    } else {

        $log->info(sprintf("RPC request was processed properly (Workflow: %01d, State: %s (%s)",
            $workflow->{id}, $workflow->{state}, $workflow->{'proc_state'}) );
        $res = { result => { id => $workflow->{id}, 'state' => $workflow->{'state'}, 'proc_state' => $workflow->{'proc_state'}, pid => $$ }};

        # Map context parameters to the response if requested
        if ($conf->{$method}->{output}) {
            $res->{result}->{data} = {};
            my @keys;
            @keys = split /\s*,\s*/, $conf->{$method}->{output};
            $log->debug("Keys " . join(", ", @keys));
            $log->trace("Raw context: ". Dumper $workflow->{context});
            foreach my $key (@keys) {
                my $val = $workflow->{context}->{$key};
                next unless (defined $val);
                next unless ($val ne '' || ref $val);
                if (OpenXPKI::Serialization::Simple::is_serialized($val)) {
                    $val = OpenXPKI::Serialization::Simple->new()->deserialize( $val );
                }
                $res->{result}->{data}->{$key} = $val;
            }
        }
    }

    send_output( $cgi,  $res );

    if ($client) {
        $client->disconnect();
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
  pki_realm = ca-one

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
  env = signer_cert, signer_dn, client_ip

The keys I<signer_cert/signer_dn> are only available on authenticated TLS
conenctions and are filled with the PEM block and the full subject dn
of the client certificate. Note that this data is only available if the
ExportCertData and StdEnvVars option is set in the apache config!

If the workflow uses endpoint specific configuraton, you must also set the
name of the server using the I<servername> key.

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

=item 40001 - no method in request

No method name could be found in the request.

=item 40002 - decoding of POST data failed

Data send as JSON POST could not be parsed. The reason is either malformed
JSON structure or the data has nested structures exceeding the parse_depth.

=item 40003 - wrong input values

The given parameters do not pass the input validation rules of the workflow.
You will find the verbose error in I<message> and the list of affected fields
in the I<fields> key.

=item 40401 - Invalid method / setup incomplete

The method name given is either not defined or has no workflow defined

=item 50001 - Error creating RPC client

The webserver was unable to setup the RPC client side. Details can be found
in the error message. Common reason is that the server is too busy or not
running and unable to handle the request at all.

=item 50002 - server exception

The server ran into an exception while handling the request, details might
be found in the error message.

=item 50003 - workflow error

The request was handled by the server properly but the workflow has
encountered an unexpected state.

=back

=head2 TLS Authentication

In case you want to use TLS Client authentication you must tell the
webserver to pass the client certificate to the script. For apache,
put the following lines into your SSL Host section:

    <Location /rpc>
        SSLVerifyClient optional
        SSLOptions +StdEnvVars +ExportCertData
    </Location>


