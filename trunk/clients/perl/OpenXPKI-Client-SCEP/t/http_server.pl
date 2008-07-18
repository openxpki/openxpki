#!/usr/bin/perl
# http_server.pl
# 
# a minimal webserver for testing the scep CGI script
#
# Written by Alexander Klink for the OpenXPKI project
# Copyright (c) 2006 by The OpenXPKI project

use strict;
use warnings;
use English;

use HTTP::Daemon;
use CGI;
use File::Temp;
use OpenXPKI;

# If there is an argument, use it as the portnumber.
# If there is none, the default port is 8087
my $port = shift || 8087;

my $daemon = HTTP::Daemon->new(
        LocalAddr => '127.0.0.1',
        LocalPort => $port,
        ReuseAddr => 1,
        );

while (my $conn = $daemon->accept()) {
    while (my $req = $conn->get_request()) {
        my $post_data;
        # if GET, the data to post to the CGI script is just the URI
        if ($req->method() eq 'GET') {
            $post_data = $req->uri();
        }
        # if POST, the data is the content of the request
        if ($req->method() eq 'POST') {
            $post_data = $req->content();
        }

        # create a new temp file for the output of the scep CGI binary
        my $tmp_file = File::Temp->new(
            TEMPLATE => 'cgioutXXXXX',
            DIR      => '/tmp',
        );
        my $tmp_filename = $tmp_file->filename();
        #$tmp_filename = '/tmp/foo';

        # call the CGI script and pass it the options using STDIN
        # (CGI qw( -debug ) in scep)
        open my $CGI_HANDLE, "| REMOTE_ADDR=127.0.0.1 ./scep > $tmp_filename 2>/dev/null";
        print $CGI_HANDLE $post_data;
        close $CGI_HANDLE;
        if ($CHILD_ERROR) {
            $conn->send_error( 501, 'scep CGI problem' );
        }

        # pass on the response of the CGI script to the HTTP client
        my $response = OpenXPKI->read_file($tmp_filename);
        if (! $response) {
            $conn->send_error( 502, 'scep response file empty' );
        }
        $conn->send_response($response);
    }
    $conn->close();
    undef($conn);
}
