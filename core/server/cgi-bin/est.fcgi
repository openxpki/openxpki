#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Fast;
use Data::Dumper;
use English;

use JSON;
use Crypt::PKCS10;
use MIME::Base64;
use Digest::SHA qw(sha1_hex);
use OpenXPKI::Exception;
use OpenXPKI::Client::Simple;
use OpenXPKI::Client::Config;
use OpenXPKI::Client::RPC;
use OpenXPKI::Serialization::Simple;

use Log::Log4perl;

our $config = OpenXPKI::Client::Config->new('est');
my $log = $config->logger();

$log->info("EST handler initialized");

my $json = new JSON();

while (my $cgi = CGI::Fast->new()) {

    # EST urls look like
    # /.well-known/est/cacerts
    # or with a label /.well-known/est/namedservice/cacerts
    # Supported operations are
    # cacerts, simpleenroll, simplereenroll, , csrattrs
    # serverkeygen and fullcmc is not supported

    $log->debug('Incoming request ' . $ENV{REQUEST_URI});
    $ENV{REQUEST_URI} =~ m{.well-known/est/((\w+)/)?(cacerts|simpleenroll|simplereenroll|csrattrs)};
    my $label = $2 || 'default';
    my $operation = $3;

    if (!$operation) {

        print $cgi->header( -status => '501 Not implemented');
        print 'Method not implemented';
        $log->error('Method not implemented');
        next;

    }

    $log->trace(sprintf("Incoming EST request %s on endpoint %s", $operation, $label));

    # set label as endpoint
    $config->endpoint($label);

    my $conf = $config->load_config();

    my $param = {};

    my $servername = $conf->{$operation}->{servername} || $conf->{global}->{servername};
    # if given, append to the paramter list
    if ($servername) {
        $param->{'server'} = $servername;
        $param->{'interface'} = 'est';
    }

    my %envkeys;
    if ($conf->{$operation}->{env}) {
        %envkeys = map {$_ => 1} (split /\s*,\s*/, $conf->{$operation}->{env});
        $log->trace("Found env keys " . $conf->{$operation}->{env});
    } elsif ($operation =~ /enroll/) {
        %envkeys = ( signer_cert => 1 );
    }

    # IP Transport
    if ($envkeys{'client_ip'}) {
        $param->{'client_ip'} = $ENV{REMOTE_ADDR};
    }

    if ($envkeys{'endpoint'}) {
        $param->{'endpoint'} = $config->endpoint();
    }

    # be lazy and use endpoint name as servername
    if ($envkeys{'server'}) {
        if ($servername) {
            $log->error("ENV server and servername are both set but are mutually exclusive");
            print $cgi->header( -status => '500 env:server and servername are mutually exclusive');
            next;
        }
        if (!$config->endpoint()) {
            $log->error("ENV server requested but endpoint is not set");
            print $cgi->header( -status => '500 env:server and servername are mutually exclusive');
            next;
        }
        $param->{'server'} = $config->endpoint();
        $param->{'interface'} = 'rpc';
    }

    # Gather data from TLS session
    my $auth_dn = '';
    my $auth_pem = '';
    if ( defined $ENV{HTTPS} && lc( $ENV{HTTPS} ) eq 'on' ) {

        $log->debug("calling context is https");
        $auth_dn = $ENV{SSL_CLIENT_S_DN};
        $auth_pem = $ENV{SSL_CLIENT_CERT};
        if ( defined $auth_dn ) {
            $log->info("EST authenticated client DN: $auth_dn");

            if ($envkeys{'signer_dn'}) {
                $param->{'signer_cert'} = $auth_dn;
            }
            if ($auth_pem && $envkeys{'signer_cert'}) {
                $param->{'signer_cert'} = $auth_pem;
            }
        }
        else {
            $log->debug("EST unauthenticated (no cert)");
        }

    } elsif ($conf->{global}->{insecure}) {
        # this violates the RFC but it might just be used as a commodity
        $log->debug("EST unauthenticated (plain http)");
    } else {
        print $cgi->header( -status => '403 Forbidden');
        print 'HTTPS required ';
        $log->error('Request via insecure connection');
        next;

    }

    # we reuse the pickup stuff and the backend factory from RPC
    my $rpc = OpenXPKI::Client::RPC->new( config => $config );

    # create the client object
    my $client = $rpc->backend();
    if ( !$client ) {
        print $cgi->header( -status => '500 Internal Server Error');
        next;
    }

    my $out;
    my $mime = "application/pkcs7-mime; smime-type=certs-only";

    $log->trace(sprintf('Extra params for %s: %s ', $operation, Dumper $param )) if ($log->is_trace());

    if ($operation eq 'cacerts') {

        my $workflow = $client->handle_workflow({
            type => $conf->{cacerts}->{workflow} || 'est_cacerts',
            params => $param
        });

        $log->trace( 'Workflow info '  . Dumper $workflow );

        $out = $workflow->{context}->{output};

        $out =~ s{-----(BEGIN|END) PKCS7-----}{}g;
        $out =~ s{\s}{}gxms;

    } elsif($operation eq 'csrattrs') {

        my $workflow = $client->handle_workflow({
            type =>  $conf->{csrattrs}->{workflow} || 'est_csrattrs',
            params => $param
        });

        $out = $workflow->{context}->{output};
        $mime = "application/csrattrs";

    } elsif($operation =~ m{simple(re)?enroll}) {

        # The CSR comes PEM encoded without borders as POSTDATA
        my $pkcs10 = $cgi->param( 'POSTDATA' );

        if (!$pkcs10) {
            print $cgi->header( -status => '400 Bad Request');
            $log->debug( 'Incoming enrollment with empty body' );
            next;
        }

        if ($pkcs10 !~ /BEGIN CERTIFICATE REQUEST/) {
            $pkcs10 = decode_base64($pkcs10);
        }

        Crypt::PKCS10->setAPIversion(1);
        my $decoded = Crypt::PKCS10->new($pkcs10, ignoreNonBase64 => 1, verifySignature => 1);
        if (!$decoded) {
            $log->error('Unable to parse PKCS10: '. Crypt::PKCS10->error);
            $log->debug($param->{pkcs10});
            print $cgi->header( -status => '400 Bad Request');
            next;
        }

        # fall back to simpleneroll config for simplereenroll if not set
        $operation = "simpleenroll" unless ($conf->{simplereenroll});

        my $pickup_config = {(
            workflow => 'certificate_enroll',
            pickup => 'pkcs10',
            pickup_attribute => 'transaction_id',
            ),
            %{$conf->{$operation}},
        };
        $log->debug(Dumper $pickup_config);

        my $transaction_id = sha1_hex($decoded->csrRequest);

        my $workflow;
        eval {

            $param->{pkcs10} = $decoded->csrRequest(1);
            Log::Log4perl::MDC->put('tid', $transaction_id);
            $param->{transaction_id} = $transaction_id;

            # check for pickup parameter
            my $pickup_value;
            # namespace needs a single value
            if ($pickup_config->{pickup_workflow}) {
                # explicit pickup paramters are set
                my @keys = split /\s*,\s*/, $pickup_config->{pickup};
                foreach my $key (@keys) {
                    # take value from param hash if defined, this makes data
                    # from the environment avail to the pickup workflow
                    my $val = $param->{$key} // $cgi->param($key);
                    $pickup_value->{$key} = $val if (defined $val);
                }
            } else {
                # pickup via transaction_id
                $pickup_value = $transaction_id;
            }

            # try pickup
            $workflow = $rpc->pickup_workflow($pickup_config, $pickup_value);

            # pickup return undef if no workflow was found - start new one
            if (!$workflow) {
                $log->debug(sprintf("Initialize %s with params %s",
                    $pickup_config->{workflow}, join(", ", keys %{$param})));
                $workflow = $client->handle_workflow({
                    type => $pickup_config->{workflow},
                    params => $param,
                });
            }

            $log->trace( 'Workflow info '  . Dumper $workflow ) if ($log->is_trace());
        };

        if (!$workflow || ( $workflow->{'proc_state'} ne 'finished' && !$workflow->{id} ) || $workflow->{'proc_state'} eq 'exception') {
            print $cgi->header( -status => '500 Internal Server Error');
            print 'Internal Server Error';
            $log->error( $EVAL_ERROR ? $EVAL_ERROR : 'Internal Server Error');
            $client->disconnect();
            next;
        }

        if ($workflow->{'proc_state'} ne 'finished') {

            # the workflow might have another idea to calculate the transaction_id
            # so if its set in the result we overwrite the initial sha1 hash
            if ($workflow->{context}->{transaction_id}) {
                $transaction_id = $workflow->{context}->{transaction_id};
            }

            my $retry_after = 300;
            if ($workflow->{'proc_state'} eq 'pause') {
                my $delay = $workflow->{'wake_up_at'} - time();
                $retry_after = ($delay > 30) ? $delay : 30;
            }

            print $cgi->header( -status => "202 Request Pending - Retry Later ($transaction_id)", "-retry-after" => $retry_after );
            print "202 Request Pending - Retry Later ($transaction_id)";
            $log->info('Request Pending - ' . $workflow->{'state'});
            $client->disconnect();
            next;
        }

        $log->trace(Dumper $workflow->{context}) if ($log->is_trace);

        my $cert_identifier = $workflow->{context}->{cert_identifier};
        if (!$cert_identifier) {
            $mime = 'text/plain';
            $out = 'Request was rejected';
            $out .= ": ".$workflow->{context}->{error_code} if ($workflow->{context}->{error_code});
        } else {
            $out = $client->run_command('get_cert',{
                format => 'PKCS7',
                identifier => $cert_identifier,
            });
            $log->debug( 'Sending cert ' . $cert_identifier);
    
            $out =~ s{-----(BEGIN|END) PKCS7-----}{}g;
            $out =~ s{\s}{}gxms;
        }

    }

    $out =~ s{^\s*}{}gxms;
    $out =~ s{\s*$}{}gxms;

    $log->trace( $out );

    print "Content-Type: $mime\n";
    printf "Content-Length: %01d\n", length $out;
    print "Content-Transfer-Encoding: base64\n";

    print "\n";
    print $out;

    $client->disconnect();

}

1;

__END__;

