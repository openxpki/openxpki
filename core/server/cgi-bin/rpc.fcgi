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
use OpenXPKI::Serialization::Simple;
use OpenXPKI::i18n qw( i18nGettext i18n_walk );

# Feature::Compat::Try should be done last to safely disable warnings
use Feature::Compat::Try;


our $config;
my $log;

my $use_status_codes = 0;
my $json = JSON::PP->new->utf8;

# Use plain scalars as boolean values. The default representation as
# JSON::PP::Boolean would cause the values to be serialized later on.
# A JSON false would be converted to a trueish scalar "OXJSF1:false".
$json->boolean_values(0,1);

my $error_msg = {
    40001 => 'No method set in request',
    40002 => 'Decoding of JSON encoded POST data failed',
    40003 => 'Wrong input values',
    40004 => 'RAW post not allowed (no method set in request)',
    40005 => 'RAW post with unknown content type',
    40006 => 'Unknown RPC error',
    40007 => 'POST data contains invalid UTF8 octets',
    40008 => 'Content type JOSE not enabled',
    40009 => 'Processing JWS protected payload failed',
    40010 => 'Method header is missing in JWS',
    40011 => 'Unsupported JWS algorithm',
    40012 => 'Content type pkcs7 not enabled',

    40101 => 'Authentication credentials missing or incorrect',

    40401 => 'Invalid method / setup incomplete',
    40402 => 'Resume requested but no workflow found',
    40403 => 'Resume requested but workflow is not in manual state',
    40404 => 'Resume requested but expected workflow action not available',

    50000 => 'Unable to fetch configuration from server - connect failed',
    50001 => 'Error creating RPC client',
    50002 => 'Server exception',
    50003 => 'Workflow terminated in unexpected state',
    50004 => 'Unable to query OpenAPI specification from OpenXPKI server',
    50005 => 'ENV variable "server" and servername are both set but are mutually exclusive',
    50006 => 'ENV variable "server" requested but RPC endpoint could not be determined from URL',
    50007 => 'Requested RPC endpoint is not configured properly',
};

# Takes the given error code and returns a HashRef like
#   {
#     error => {
#       code => 50000,
#       message => "...",
#       data => { pid => $$, ... },
#     }
#   }
# Also logs the error via $log->error().
#
# Parameters:
#   $code - error code (Int)
#   $message - optional: additional error message (Str)
#   $messages - optional: two different messages for logging (internal) and client result (public) (ArrayRef)
#   $data - optional: additional information for 'data' part (HashRef)
#
# Example:
#   failure(50007, [ "Public error message", "Internal error: $eval_err" ]);
sub failure {
    my $code = shift;
    my @args = @_;

    my $message = $error_msg->{$code} // 'Unknown error';
    my $data = { pid => $$ };
    my $details_log = '';
    my $details_public = '';

    # check remaining arguments
    for my $arg (@args) {
        # Scalar = additional error message
        if (not ref $arg and length($arg)) {
            $details_public = ': '.$arg;
            $details_log = ': '.$arg;
        }
        # ArrayRef = two different additional error messages [external, internal]
        elsif (ref $arg eq 'ARRAY') {
            $details_public = ': '.$arg->[0];
            $details_log = ': '.$arg->[1];
        }
        # HashRef = additional data
        elsif (ref $arg eq 'HASH') {
            $data = { %$data, %$arg };
        }
    }

    # $log might not yet be initialised
    $log ? $log->error("$code - $message$details_log") : warn "$code - $message";

    return {
        error => {
            code => $code,
            message => $message.$details_public,
            data => $data,
        },
        rpc_failure => 1, # flag to help error handling
    }
}

sub send_output {
    my ($cgi, $result, $canonical_keys) = @_;

    $log->trace("Raw result: ". Dumper $result) if ($log->is_trace());

    my $status = '200 OK';
    my %retry_head;
    if (defined $result->{error}) {
        delete $result->{rpc_failure};
        if ($use_status_codes) {
            my ($error) = split(/[:\n]/, i18nGettext($result->{error}->{message}));
            $status = sprintf ("%03d %s", ($result->{error}->{code}/100), $error);
        }
    } elsif ($use_status_codes && $result->{result} && $result->{result}->{retry_after}) {
        $status = '202 Request Pending - Retry Later';
        %retry_head = ("-retry-after" => $result->{result}->{retry_after} );
    }

    if ($ENV{'HTTP_ACCEPT'} && $ENV{'HTTP_ACCEPT'} eq 'text/plain') {
       print $cgi->header( -type => 'text/plain', charset => 'utf8', -status => $status, %retry_head );
       if (my $e = $result->{error}) {
           print 'error.code=' . $e->{code}."\n";
           print 'error.message=' . $e->{message}."\n";
           map { printf "data.%s=%s\n", $_, $e->{data}->{$_} } keys $e->{data}->%* if $e->{data};

       } elsif (my $s = $result->{result}) {
           print 'id=' . $s->{id}."\n";
           print 'state=' . $s->{state}."\n";
           print 'retry_after=' . $s->{retry_after} ."\n" if $s->{retry_after};
           map { printf "data.%s=%s\n", $_, $s->{data}->{$_} } keys $s->{data}->%* if $s->{data};
       }

    } else {
        print $cgi->header( -type => 'application/json', charset => 'utf8', -status => $status, %retry_head );
        $json->max_depth(20);
        $json->canonical( $canonical_keys ? 1 : 0 );

        # run i18n tokenzier on output if a language is set
        print $json->encode( $config->language ? i18n_walk($result) : $result );
    }
}


eval {
    $config = OpenXPKI::Client::Config->new('rpc');
    $log = $config->logger();
};

if ($EVAL_ERROR) {
    my $cgi = CGI::Fast->new();
    print $cgi->header( -type => 'application/json', charset => 'utf8', -status => '500 Client Connect Failed' );
    print $json->encode( failure(50000) );
    die "Client Connect Failed: $EVAL_ERROR";
}

$log->info("RPC handler initialized");

CGI_LOOP:
while (my $cgi = CGI::Fast->new()) {
    my $client;

    try {
        my $ep_config;
        my ($endpoint, $route);
        eval {
            ($endpoint, $route) = $config->parse_uri;
            $ep_config = $config->endpoint_config($endpoint);
        };
        my $eval_err = $EVAL_ERROR;

        die failure( 50007, [undef, $eval_err] ) unless $ep_config;

        my $rpc = OpenXPKI::Client::Service::RPC->new(
            config_obj => $config,
            endpoint => $endpoint,
            error_messages => $error_msg,
        );

        $use_status_codes = $ep_config->{output} && $ep_config->{output}->{use_http_status_codes};

        # check for request parameters in JSON data (HTTP body)
        my $method = $cgi->param('method');
        my $json_data;
        my $pkcs7_content;
        my $pkcs7;
        my $jwt_header;
        if (my $raw = $cgi->param('POSTDATA')) {

            die failure( 40004 ) unless $ep_config->{input}->{allow_raw_post};

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

                die failure( 40008 ) unless $ep_config->{jose};

                # The cert_identifier used to sign the token must be set as kid
                # First run - set ignore_signature to just get the header with the kid
                my ($cert_identifier, $cert);
                ($jwt_header) = decode_jwt(token=> $raw, ignore_signature => 1, decode_header => 1, decode_payload => 0);

                if ($jwt_header->{alg} !~ m{\A(R|E)S256\z}) {
                    die failure( 40011, { alg => $jwt_header->{alg} } );
                }

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
                    die failure( 40009, "No key id was found in the JWT header" );
                }

                # to prevent nasty attacks we require that the method name is part of the protected header
                $method = $jwt_header->{method} || die failure( 40010 );

                $client = $rpc->backend();
                try {
                    # this will die if the certificate was not found
                    # TOOD - this call fails if no backend connection can be made which gives a misleading
                    # error code to the customer - this can also happen on a misconfigured auth stack :)
                    # might also be useful to have a validated "certificate" used for the session login
                    # so the likely best option would be some kind on "anonymous" client here
                    # See #903 and #904 on github
                    $cert = $client->run_command('get_cert', { identifier => $cert_identifier, format => 'PEM' });

                    # use our json parser object to decode to limit parsing depth
                    ($raw) = decode_jwt(token => $raw, key => \$cert, decode_payload => 0);
                    $log->trace("Encoded JSON postdata: " . $raw) if ($log->is_trace());

                    $jwt_header->{signer_cert} = $cert;

                } catch ($err) {

                    die failure( 40009, [ 'Given key id was not found', $err ] ) unless($cert);

                    die failure( 40009, [ 'JWT signature could not be verified', $err ] );
                }

            } elsif ($content_type =~ m{\Aapplication/pkcs7}) {

                die failure( 40012 ) unless $ep_config->{pkcs7};

                $pkcs7 = $raw;
                eval {
                    $client = $rpc->backend();
                    $pkcs7_content = $client->run_command('unwrap_pkcs7_signed_data', {
                        pkcs7 => $pkcs7,
                    });
                    $raw = $pkcs7_content->{value};
                    $log->trace("PKCS7 content: " . Dumper  $pkcs7_content) if ($log->is_trace());
                };
                $eval_err = $EVAL_ERROR;
                if ($eval_err || !$raw) {
                    die failure( 50001, $eval_err );
                }

                $log->trace("PKCS7 payload: " . $raw) if ($log->is_trace());

            } elsif ($content_type =~ m{\Aapplication/json}) {

                $log->trace("Encoded JSON postdata: " . $raw) if ($log->is_trace());

            } else {

                die failure( 40005, { type => $content_type } );
            }

            # decode JSON
            eval{ $json_data = $json->decode($raw) } if ($raw);

            die failure( 40002, [ '', $EVAL_ERROR ] ) if (!$json_data or $EVAL_ERROR);
            # read "method" from JSON data if not found in URL before
            $method = $json_data->{method} unless $method;
        }

        # accessor that takes a key and returns either JSON value (if available)
        # or the CGI param value.
        my $get_param = sub {
            my $k = shift;
            if ($json_data) {
                return $json_data->{$k}; # UTF-8 decoding already done by JSON modules
            }
            else {
                my $raw = $cgi->param($k);  # assume this is an UTF-8 encoded octet stream
                return unless defined $raw; # ..to be able to test for undef below
                # decode UTF-8
                my $value = eval { Encode::decode("UTF-8", $raw, Encode::LEAVE_SRC | Encode::FB_CROAK) }
                    // die failure(40007, [undef, "Could not decode field '$k' - $EVAL_ERROR"]);
                return $value;
            }
        };

        $method ||= $route;

        # method should be set now
        die failure( 40001 ) unless $method;

        # special handling for requests for OpenAPI (Swagger) spec
        if ($method eq 'openapi-spec') {
            my $baseurl = sprintf "%s://%s:%s%s", ($cgi->https ? 'https' : 'http'), $cgi->virtual_host, $cgi->virtual_port, $cgi->request_uri;
            my $spec = $rpc->openapi_spec($baseurl) or die failure( 50004 );
            send_output($cgi, $spec, 1);
            next CGI_LOOP;
        }

        my $servername = $ep_config->{$method}->{servername} || '';
        Log::Log4perl::MDC->put('server', $servername);

        my $error = '';

        # "workflow" is required even though with "execute_action" we don't need it.
        # But the check here serves as a config validator so that a correct OpenAPI
        # Spec will be generated upon request.
        my $workflow_type = $ep_config->{$method}->{workflow};
        die failure( 40401, "RPC method $method not found or no workflow_type set" )
          unless defined $workflow_type;

        my $param;
        # look for preset params
        foreach my $key (keys %{$ep_config->{$method}}) {
            next unless ($key =~ m{preset_(\w+)});
            $param->{$1} = $ep_config->{$method}->{$key};
        }

        # Only parameters which are whitelisted in the config are mapped!
        # This is crucial to prevent injection of server-only parameters
        # like the autoapprove flag...

        if ($ep_config->{$method}->{param}) {
            my @keys;
            @keys = split /\s*,\s*/, $ep_config->{$method}->{param};
            foreach my $key (@keys) {
                my $val = $get_param->($key);
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
        if ($ep_config->{$method}->{env}) {
            %envkeys = map {$_ => 1} (split /\s*,\s*/, $ep_config->{$method}->{env});
        }

        # IP Transport
        if ($envkeys{'client_ip'}) {
            $param->{'client_ip'} = $ENV{REMOTE_ADDR};
        }

        # User Agent
        if ($envkeys{'user_agent'}) {
            $param->{'user_agent'} = $ENV{HTTP_USER_AGENT};
        }

        # be lazy and use endpoint name as servername
        if ($envkeys{'server'}) {
            if ($servername) {
                die failure( 50005 );
            } elsif (!$endpoint) {
                die failure( 50006 );
            } else {
                $param->{'server'} = $endpoint;
                $param->{'interface'} = 'rpc';
                Log::Log4perl::MDC->put('server', $param->{'server'} );
            }
        }

        if ($envkeys{'endpoint'}) {
            $param->{'endpoint'} = $endpoint;
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
                    $param->{'signer_dn'} = $auth_dn;
                }

                if ($envkeys{'tls_client_dn'}) {
                    $param->{'tls_client_dn'} = $auth_dn;
                }

                if ($auth_pem) {
                    $param->{'signer_cert'} = $auth_pem if ($envkeys{'signer_cert'});
                    $param->{'tls_client_cert'} = $auth_pem if ($envkeys{'tls_client_cert'});
                    if (($envkeys{'signer_chain'} || $envkeys{'tls_client_chain'}) && $ENV{'SSL_CLIENT_CERT_CHAIN_0'}) {
                        my @chain;
                        for (my $cc=0;$cc<=3;$cc++)   {
                            my $chaincert = $ENV{'SSL_CLIENT_CERT_CHAIN_'.$cc};
                            last unless ($chaincert);
                            push @chain, $chaincert;
                        }
                        $param->{'signer_chain'} = $auth_pem if ($envkeys{'signer_chain'});
                        $param->{'tls_client_chain'} = $auth_pem if ($envkeys{'tls_client_chain'});
                    }
                }
            }
            else {
                $log->debug("RPC unauthenticated (no cert)");
            }
        } else {
            $log->debug("RPC unauthenticated (plain http)");
        }

        if ($pkcs7_content && $envkeys{'pkcs7'}) {
            $param->{'_pkcs7'} = $pkcs7;
        }

        if ($pkcs7_content && $envkeys{'signer_cert'}) {
            $param->{'signer_cert'} = $pkcs7_content->{signer};
        }

        if ($jwt_header && $envkeys{'signer_cert'}) {
            $param->{'signer_cert'} = $jwt_header->{signer_cert};
        }

        $log->trace( "Calling '$method' on '$endpoint' with parameters: " . Dumper $param ) if $log->is_trace;

        my $res;
        my $workflow;

        try {
            # create the client object
            $client = $rpc->backend() or die failure( 50001, "Unable to create client" );

            # check for pickup parameter
            if (my $pickup_key = $ep_config->{$method}->{pickup}) {
                my $pickup_value;
                # "pickup_workflow" needs a parameter HashRef
                if ($ep_config->{$method}->{pickup_workflow}) {
                    my @keys = split /\s*,\s*/, $pickup_key;
                    foreach my $key (@keys) {
                        # take value from param hash if defined, this makes data
                        # from the environment avail to the pickup workflow
                        my $val = $param->{$key} // $get_param->($key);
                        $pickup_value->{$key} = $val if (defined $val);
                    }
                # "pickup_namespace" and "pickup_attribute" need a single value - see pickup_workflow()
                } else {
                    $pickup_value = $get_param->($pickup_key);
                }
                if ($pickup_value) {
                    $workflow = $rpc->pickup_workflow($ep_config->{$method}, $pickup_value);
                } else {
                    $log->trace( "No pickup because $pickup_key has no value" ) if $log->is_trace;
                }
            }

            # Endpoint has a "resume and execute" definition so run action if possible
            #
            # If "execute_action" is defined it enforces "pickup_workflow" and we never
            # start a new workflow, even if no "pickup" parameters were given.
            if (my $execute_action = $ep_config->{$method}->{execute_action}) {
                if (!$workflow) {
                    die failure( 40402 );
                } elsif ($workflow->{'proc_state'} ne 'manual') {
                    die failure( 40403, { id => int($workflow->{id}), 'state' => $workflow->{'state'}, proc_state => $workflow->{'proc_state'} } );
                } else {
                    my $actions_avail = $client->run_command('get_workflow_activities', { id => $workflow->{id} });
                    if (!(grep { $_ eq  $execute_action } @{$actions_avail})) {
                        die failure( 40404, { id => int($workflow->{id}), 'state' => $workflow->{'state'}, proc_state => $workflow->{'proc_state'} } );
                    } else {
                        $log->debug("Resume #".$workflow->{id}." and $execute_action with params " . join(", ", keys %{$param}));
                        $workflow = $client->handle_workflow({
                            id => $workflow->{id},
                            activity => $execute_action,
                            params => $param
                        });
                    }
                }

            # pickup return undef if no workflow was found
            } elsif (!$workflow) {
                $log->debug("Initialize $workflow_type with params " . join(", ", keys %{$param}));
                $workflow = $client->handle_workflow({
                    type => $workflow_type,
                    params => $param
                });
            }

            $log->trace( 'Workflow info '  . Dumper $workflow ) if ($log->is_trace());
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

            if ( blessed $err ) {

                die failure( 40101, $err->message )
                    if ($err->isa('OpenXPKI::Exception::Authentication'));

                die failure( 50002, $err->message )
                    if ($err->isa('OpenXPKI::Exception'));
            }

            #
            # Validation error
            #

            my $error = $client->last_error() || $err;
            my $reply = $client->last_reply();
            # TODO this needs to be reworked
            if ($reply->{ERROR}
                && ($reply->{ERROR}->{CLASS}//'') eq 'OpenXPKI::Exception::InputValidator'
                && $reply->{ERROR}->{ERRORS}
            ) {

                $log->trace(Dumper $reply);
                my $error = join ", ", map { $_->{name} }  @{$reply->{ERROR}->{ERRORS}};
                die failure( 40003, $error || $reply->{ERROR}->{LABEL} || '', { fields => $reply->{ERROR}->{ERRORS} } );

            } else {
                if ($reply->{ERROR} && $reply->{ERROR}->{LABEL}) {
                    $error = $reply->{ERROR}->{LABEL};
                }
                my $msg_public = (($error//'') =~ /I18N_OPENXPKI_UI_/) ? $error : 'uncaught error';
                my $msg_log = $error;
                die failure( 50002, [ $msg_public, $msg_log ] );
            }
        }

        if (not $res) {
            # no ID and not finished is an unrecoverable startup error
            if (( $workflow->{'proc_state'} ne 'finished' && !$workflow->{id} ) || $workflow->{'proc_state'} eq 'exception') {

                die failure( 50003, { id => int($workflow->{id}), 'state' => $workflow->{'state'} } );

            # if the workflow is running, we do not expose any data of the workflows
            } elsif ( $workflow->{'proc_state'} eq 'running' ) {

                $log->info(sprintf("RPC request was processed properly (Workflow: %01d is currently running)",
                    $workflow->{id} ));
                $res = { result => { id => int($workflow->{id}), 'state' => '--', 'proc_state' => $workflow->{'proc_state'}, pid => $$ }};

            } else {

                $log->info(sprintf("RPC request was processed properly (Workflow: %01d, State: %s (%s))",
                    $workflow->{id}, $workflow->{state}, $workflow->{'proc_state'}) );
                $res = { result => { id => int($workflow->{id}), 'state' => $workflow->{'state'}, 'proc_state' => $workflow->{'proc_state'}, pid => $$ }};

                # if pickup is set and workflow is not in a final state we send a 202
                if ($ep_config->{$method}->{pickup}) {
                    if ($workflow->{'proc_state'} eq 'pause') {
                        my $delay = $workflow->{'wake_up_at'} - time();
                        $res->{result}->{retry_after} = ($delay > 30) ? $delay : 30;
                        $log->debug("Need retry - workflow is paused - delay $delay");
                    } elsif ($workflow->{'proc_state'} ne 'finished') {
                        $res->{result}->{retry_after} = 300;
                        $log->debug("Need retry - workflow is " . $workflow->{'proc_state'});
                    }
                }

                # Map context parameters to the response if requested
                if ($ep_config->{$method}->{output}) {
                    $res->{result}->{data} = {};
                    my @keys;
                    @keys = split /\s*,\s*/, $ep_config->{$method}->{output};
                    $log->debug("Keys " . join(", ", @keys));
                    $log->trace("Raw context: ". Dumper $workflow->{context}) if ($log->is_trace());
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
        }
        send_output( $cgi,  $res );
    }
    catch ($err) {
        # special internal error hash generated by failure()
        if (ref $err eq 'HASH' and defined $err->{rpc_failure}) {
            send_output( $cgi, $err );
        }
        # unknown error
        else {
            send_output( $cgi, failure(40006, [ undef, $err ]) );
        }
    }
    finally {
        $client->disconnect() if $client;
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

=item 40001 - no method in request

No method name could be found in the request.

=item 40002 - decoding of JSON encoded POST data failed

Data send as JSON POST could not be parsed. The reason is either malformed
JSON structure or the data has nested structures exceeding the parse_depth.

=item 40003 - wrong input values

The given parameters do not pass the input validation rules of the workflow.
You will find the verbose error in I<message> and the list of affected fields
in the I<fields> key.

=item 40004 - RAW Post not allowed

RAW post was detected but is not allowed by configuration.

=item 40005 - RAW Post with unknown Content-Type

The Content-Type set with a RAW post request is not known.
Supported types are application/json and application/pkcs7.

=item 40401 - Invalid method / setup incomplete

The method name given is either not defined or has no workflow defined

=item 40402 - Resume requested but nothing to pickup

The method name has an execute statement but no workflow to be continued
was found using the given pickup rules

=item 40403 - Resume requested but workflow is not in manual state

The method name has an execute statement but the loaded workflow is
not in a state that accepts external input

=item 40404 - Resume requested but expected method is not available

The method name has an execute statement but the expected activity is
not available in the loaded workflow

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

=item 50004 - error getting OpenAPI spec

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
