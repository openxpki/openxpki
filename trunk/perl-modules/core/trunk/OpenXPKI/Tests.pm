## OpenXPKI::Tests;
##
## Written 2007 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project
## $Revision$
package OpenXPKI::Tests;

use strict;
use warnings;
use English;

use OpenXPKI::Client;
use Test::More;
use File::Path;
use Cwd;

use Data::Dumper;

use vars qw( @EXPORT );
use Exporter 'import';
@EXPORT = qw(
                deploy_test_server
                start_test_server
                login
                is_error_response
                isnt_deeply
            ); 

sub deploy_test_server {
    my $arg_ref     = shift;
    my $instancedir = $arg_ref->{DIRECTORY};
    diag("Locally deploying OpenXPKI");

    # check if infrastructure commands are installed
    if (system("openxpkiadm >/dev/null 2>&1") != 0) {
        diag("openxpkiadm is not installed!");
        return 0;
    }

    if (! mkpath($instancedir)) {
        diag("$instancedir could not be created");
        return 0;
    }

    # be quiet by default
    my $stderr = '>/dev/null 2>/dev/null';
    if ($ENV{DEBUG}) {
        $stderr = '';
    }

    # deployment
    if(system("openxpkiadm deploy --prefix $instancedir $stderr")) {
        diag("openxpkiadm deploy failed");
        return 0;
    }

    # meta config should now exist
    if(! -e "$instancedir/etc/openxpki/openxpki.conf") {
        diag("openxpki.conf does not exist");
        return 0;
    }

    my ($pw_name) = getpwuid($EUID);
    my ($gr_name) = getgrgid($EUID);
    my %configure_settings = (
        'dir.prefix'        => File::Spec->rel2abs($instancedir),
        'dir.dest'          => File::Spec->rel2abs($instancedir),
        'server.socketfile' => "$instancedir/var/openxpki/openxpki.socket",
        'server.runuser'    => $pw_name,
        'server.rungroup'   => $gr_name,
        'database.type'     => 'SQLite',
        'database.name'     => "$instancedir/var/openxpki/sqlite.db",
    );

    # configure in this directory
    my $dir = getcwd();
    if(! chdir $instancedir) {
        diag("Could not change to $instancedir");
        return 0;
    }

    my $args = "--batch --createdirs --";
    foreach my $key (keys %configure_settings) {
        $args .= " --setcfgvalue $key=$configure_settings{$key}";
    }
    if(system("openxpki-configure $args $stderr")) {
        diag("openxpki-configure failed");
        return 0;
    }

    # and back
    chdir($dir);

    if (! -e "$instancedir/etc/openxpki/config.xml") {
        diag("config.xml does not exist");
        return 0;
    }

    $args = '';
    if ($ENV{DEBUG}) {
        $args .= ' --debug 128 ';
    }
    if(system("openxpkiadm initdb $args --config $instancedir/etc/openxpki/config.xml $stderr")) {
        diag("openxpkiadm initdb failed");
        return 0;
    }
    return 1;
}

sub start_test_server {
    my $arg_ref     = shift;
    my $instancedir = $arg_ref->{DIRECTORY};
    if (! defined $instancedir) {
        diag "No DIRECTORY passed";
        return 0;
    }
    my $configfile  = $instancedir . '/etc/openxpki/config.xml';

    my $stderr = '>/dev/null 2>/dev/null';
    if ($ENV{DEBUG}) {
        $stderr = '';
    }
    my $args = '';
    if ($arg_ref->{FOREGROUND}) {
        $args = '--foreground';
    }
    if ($ENV{DEBUG}) {
        $args .= ' --debug 128 ';
    }
    return ! system("openxpkictl --config $configfile $args start $stderr");
}

sub login {
    my $arg_ref = shift;
    my $client  = $arg_ref->{CLIENT};
    my $user    = $arg_ref->{USER};
    my $pass    = $arg_ref->{PASSWORD};

    $client->init_session();

    my $msg = $client->send_receive_service_msg(
        'GET_AUTHENTICATION_STACK',
        {
            'AUTHENTICATION_STACK' => 'External Dynamic',
        },
    );
    if (is_error_response($msg)) {
        diag "Login failed (stack selection): " . Dumper $msg;
        return 0;
    }
    $msg = $client->send_receive_service_msg(
        'GET_PASSWD_LOGIN',
        {
            'LOGIN'  => $user,
            'PASSWD' => $pass,
        },
    );
    if (is_error_response($msg)) {
        diag "Login failed: " . Dumper $msg;
        return 0;
    }

    return 1;
}

sub is_error_response {
    my $msg = shift;
    if (exists $msg->{'SERVICE_MSG'} &&  $msg->{'SERVICE_MSG'} eq 'ERROR') {
        return 1;
    }
    else {
        return 0;
    }
}

sub isnt_deeply {
    my $a    = shift;
    my $b    = shift;
    my $name = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    ok(! Test::More::_deep_check($a, $b), $name);
}


1;
__END__

=head1 Name

OpenXPKI::Tests

=head1 Description

This is a helper module for the OpenXPKI test suites. It 
adds a lot of helper functions for deploying, starting,
stopping a server as well as own test functions that add tests for
various things.

=head1 Functions

All of these functions are exported into the caller namespace for
easier calling (and because it is assumed that tests don't use
much of the namespace for themselves anyways).

=head2 deploy_test_server

Deploys test server configuration. Takes a named argument of 'DIRECTORY',
which is the directory into which the server will be deployed.
Returns 1 if deployment was successfull, 0 otherwise.

=head2 start_test_server

Starts the deployed test server. Takes an optional argument of
FOREGROUND, which will start the server in the foreground (this is
useful so that a forked child can send commands to the server and
the coverage report gets server information instead of client information).
The named argument 'DIRECTORY' is the one used in deploy_test_server()
to find the corresponding configuration file.
Returns 1 if starting the server was successfull, 0 otherwise.

=head2 login

Expects the named arguments CLIENT (which is an OpenXPKI::Client object),
USER and PASSWORD. Initializes the client session and logs the user in
using the Operator stack and the given username and password.
Returns 1 on success, 0 on failure.

=head2 is_error_response

Expects a message returned by a call to send_receive_command_msg().
Returns 1 if the response from the server signifies an error, 0 otherwise.

=head2 isnt_deeply

Checks that structures differ deeply. This is the opposite of
is_deeply from Test::More.
