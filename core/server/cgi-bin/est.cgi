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
    $ENV{REQUEST_URI} =~ m{.well-known/est/(\w+/)?(cacerts|simpleenroll|simplereenroll|csrattrs)};
    my $label = $1;
    my $operation = $2;

    if (!$operation) {

        print $cgi->header( -status => '501 Not implemented');
        print 'Method not implemented';
        $log->error('Method not implemented');
        next;

    }

    my $conf =  $label ? $config->load_config($label) : $config->default();

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

    my $params = {
        server => 'default',
        interface => 'est',
    };

    my $out;
    my $mime = "application/pkcs7-mime; smime-type=certs-only";

    if ($operation eq 'cacerts') {

        my $workflow = $client->handle_workflow({
            TYPE => 'est_cacerts',
            PARAMS =>$params
        });

        $log->trace( 'Workflow info '  . Dumper $workflow );

        $out = $workflow->{CONTEXT}->{output};

        $out =~ s{-----(BEGIN|END) PKCS7-----}{}g;
        $out =~ s{\s}{}gxms;

    } elsif($operation eq 'csrattrs') {

        my $workflow = $client->handle_workflow({
            TYPE => 'est_csrattrs',
            PARAMS => $params
        });

        $out = $workflow->{CONTEXT}->{output};
        $mime = "application/csrattrs";

    } elsif($operation eq 'simpleenroll') {

        # The CSR comes PEM encoded without borders as POSTDATA
        my $pkcs10 = $cgi->param( 'POSTDATA' );
        if (!$pkcs10) {
            print $cgi->header( -status => '400 Bad Request');
            $log->debug( 'Incoming enrollment with empty body' );
            next;
        }

        $params->{pkcs10} = "-----BEGIN CERTIFICATE REQUEST-----\n$pkcs10\n-----END CERTIFICATE REQUEST-----";

        $log->debug( 'Workflow Params '  . Dumper $params);

        my $workflow = $client->handle_workflow({
            TYPE => 'est_enroll',
            PARAMS => $params
        });

        my $cert_identifier = $workflow->{CONTEXT}->{cert_identifier};
        $out = $client->run_command('get_cert',{
            FORMAT => 'PKCS7',
            IDENTIFIER => $cert_identifier,
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


}
