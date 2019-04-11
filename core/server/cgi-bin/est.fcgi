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
    # cacerts, simpleenroll, simplereenroll, fullcmc, serverkeygen, csrattrs

    $log->debug('Incoming request ' . $ENV{REQUEST_URI});
    $ENV{REQUEST_URI} =~ m{.well-known/est/((\w+)/)?(cacerts|simpleenroll|simplereenroll|csrattrs)};
    my $label = $2 || '';
    my $operation = $3;

    if (!$operation) {

        print $cgi->header( -status => '501 Not implemented');
        print 'Method not implemented';
        $log->error('Method not implemented');
        next;

    }

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

    # create the client object
    my $client = OpenXPKI::Client::Simple->new({
        logger => $log,
        config => $conf->{global}, # realm and locale
        auth => $conf->{auth}, # auth config
    });

    if ( !$client ) {
        print $cgi->header( -status => '500 Internal Server Error');
        next;
    }


    my $out;
    my $mime = "application/pkcs7-mime; smime-type=certs-only";

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

    } elsif($operation eq 'simpleenroll') {

        # The CSR comes PEM encoded without borders as POSTDATA
        my $pkcs10 = $cgi->param( 'POSTDATA' );

        if (!$pkcs10) {
            print $cgi->header( -status => '400 Bad Request');
            $log->debug( 'Incoming enrollment with empty body' );
            next;
        }

        if ($pkcs10 =~ /BEGIN CERTIFICATE REQUEST/) {
            $param->{pkcs10} = $pkcs10;
        } else {
            $param->{pkcs10} = "-----BEGIN CERTIFICATE REQUEST-----\n$pkcs10\n-----END CERTIFICATE REQUEST-----";
        }

        Crypt::PKCS10->setAPIversion(1);
        my $decoded = Crypt::PKCS10->new($param->{pkcs10}, ignoreNonBase64 => 1, verifySignature => 1);
        if (!$decoded) {
            $log->error('Unable to parse PKCS10: '. Crypt::PKCS10->error);
            $log->debug($param->{pkcs10});
            print $cgi->header( -status => '400 Bad Request');
            next;
        }
        my $transaction_id = sha1_hex($decoded->csrRequest);

        Log::Log4perl::MDC->put('tid', $transaction_id);
        $param->{transaction_id} = $transaction_id;

        my $workflow_type = $conf->{simpleenroll}->{workflow} || 'certificate_enroll';

        my $wfl = $client->run_command('search_workflow_instances', {
            type => $workflow_type,
            attribute => { transaction_id => $transaction_id },
            limit => 2
        });

        my $workflow;
        if (@$wfl > 1) {

            print $cgi->header( -status => '500 Internal Server Error');
            print 'Internal Server Error';
            $log->error('Internal Server Error - ambigous workflow result on transaction id ' .$transaction_id);
            $client->disconnect();

        } elsif (@$wfl == 1) {
            my $wf_id = $wfl->[0]->{workflow_id};
            $workflow = $client->handle_workflow({
                type => $workflow_type,
                id => $wf_id
            });
            $log->info('Found workflow - reload ' .$wf_id );
        } else {
            $workflow = $client->handle_workflow({
                type => $workflow_type,
                params => $param
            });
            $log->info('Started new workflow ' . $workflow->{id});
            $log->trace( 'Workflow Params '  . Dumper $param);
        }

        if (( $workflow->{'proc_state'} ne 'finished' && !$workflow->{id} ) || $workflow->{'proc_state'} eq 'exception') {
            print $cgi->header( -status => '500 Internal Server Error');
            print 'Internal Server Error';
            $log->error('Internal Server Error');
            $client->disconnect();
            next;
        }

        if ($workflow->{'proc_state'} ne 'finished') {
            print $cgi->header( -status => '503 Request Pending - Retry Later ($transaction_id)', "-retry-after" => 300 );
            print "503 Request Pending - Retry Later ($transaction_id)";
            $log->info('Request Pending - ' . $workflow->{'state'});
            $client->disconnect();
            next;
        }

        $log->trace(Dumper $workflow->{context}) if ($log->is_trace);

        my $cert_identifier = $workflow->{context}->{cert_identifier};
        $out = $client->run_command('get_cert',{
            format => 'PKCS7',
            identifier => $cert_identifier,
        });
        $log->debug( 'Sending cert ' . $cert_identifier);

        $out =~ s{-----(BEGIN|END) PKCS7-----}{}g;
        $out =~ s{\s}{}gxms;

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

