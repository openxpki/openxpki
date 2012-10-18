## OpenXPKI::Tests
##
## Written 2007 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project
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
                create_ca_cert
            ); 

sub deploy_test_server {
    my $arg_ref     = shift;
    my $instancedir = $arg_ref->{DIRECTORY};
    my $opensslfile = '';
    if (-e 't/cfg.binary.openssl') {
        open my $OPENSSLCFG, '<', 't/cfg.binary.openssl';
        $opensslfile = <$OPENSSLCFG>;
        close $OPENSSLCFG;
        $opensslfile = '' if ((! (-e $opensslfile)) || (!(-x _ )) || (`$opensslfile version` !~ m{\A OpenSSL\ 0\.9\.8 }xms));
    }

    diag("Locally deploying OpenXPKI");

    # check if infrastructure commands are installed

    my $openxpkiadm = "openxpkiadm";
    my $openxpki_configure = "openxpki-configure";
    if ($ENV{DEPLOYMENT_PREFIX}) {
        diag "Deployment prefix is: $ENV{DEPLOYMENT_PREFIX}\n ";
        $openxpkiadm = $ENV{DEPLOYMENT_PREFIX}."/$openxpkiadm" 
            if (-e $ENV{DEPLOYMENT_PREFIX}."/$openxpkiadm" && -x _);
        diag "Using openxpkiadm: $openxpkiadm\n ";
        $openxpki_configure = $ENV{DEPLOYMENT_PREFIX}."/$openxpki_configure" 
            if (-e $ENV{DEPLOYMENT_PREFIX}."/$openxpki_configure" && -x _);
        diag "Using openxpki-configure: $openxpki_configure\n ";
        $ENV{PATH} = $ENV{DEPLOYMENT_PREFIX}.":".$ENV{PATH};
    }

    if (system("$openxpkiadm >/dev/null 2>&1") != 0) {
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
    if(system("$openxpkiadm deploy --prefix $instancedir $stderr")) {
        diag("openxpkiadm deploy failed");
        return 0;
    }

    # meta config should now exist
    if(! -e "$instancedir/etc/openxpki/openxpki.conf") {
        diag("openxpki.conf does not exist");
        return 0;
    }

    my ($pw_name) = getpwuid($EUID);
    my ($gr_name) = getgrgid($EGID);
    my %configure_settings = (
        'dir.prefix'        => File::Spec->rel2abs($instancedir),
        'dir.dest'          => File::Spec->rel2abs($instancedir),
        'server.socketfile' => "$instancedir/var/openxpki/openxpki.socket",
        'server.runuser'    => $pw_name,
        'server.rungroup'   => $gr_name,
        'database.type'     => 'SQLite',
        'database.name'     => "$instancedir/var/openxpki/sqlite.db",
    );
    $configure_settings{'file.openssl'} = $opensslfile if ($opensslfile);

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
    if(system("$openxpki_configure $args $stderr")) {
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
    if(system("$openxpkiadm initdb $args --config $instancedir/etc/openxpki/config.xml $stderr")) {
        diag("openxpkiadm initdb failed");
        return 0;
    }
    return 1;
}

sub create_ca_cert {
    my $arg_ref     = shift;
    my $instancedir = $arg_ref->{DIRECTORY};
    my $configfile;
    $configfile = $arg_ref->{CONFIGFILE} if ($arg_ref->{CONFIGFILE});

    my $openssl = 'openssl';
    if ($arg_ref->{OPENSSL_FILE}) {
        $openssl = $arg_ref->{OPENSSL_FILE};
        $openssl = 'openssl' if ( (! (-e $openssl)) || (!(-x _ )) );
    }

    if (! (`$openssl version` =~ m{\A OpenSSL\ 0\.9\.8 }xms)) {
        diag "OpenSSL 0.9.8 not available";
        return 0;
    }

    if (! $configfile || ! -e $configfile) {
        diag "Trying to use default OpenSSL config file.";
        $configfile = '';
    }
    else {
        $configfile = cwd()."/$configfile" if ($configfile !~ m{ \A \/ }xms );
        diag "Using local OpenSSL config file ($configfile).";
        $configfile = "-config $configfile";
    }

    my $openxpkiadm = "openxpkiadm";
    if ($ENV{DEPLOYMENT_PREFIX}) {
        diag "Using deployment prefix: $ENV{DEPLOYMENT_PREFIX}\n ";
        $openxpkiadm = $ENV{DEPLOYMENT_PREFIX}."/$openxpkiadm" 
            if (-e $ENV{DEPLOYMENT_PREFIX}."/$openxpkiadm" && -x _);
    }

    `mkdir -p $instancedir/etc/openxpki/ca/testdummyca1/`;
    if ($CHILD_ERROR) {
        diag "Could not create directory";
        return 0;
    }

    `pwd=1234567890 $openssl genrsa -des -passout env:pwd -out $instancedir/etc/openxpki/ca/testdummyca1/cakey.pem`;
    if ($CHILD_ERROR) {
        diag "Could not generate CA key";
        return 0;
    }
    `(echo '.'; echo '.'; echo '.'; echo 'OpenXPKI'; echo 'Testing CA'; echo 'Testing CA'; echo '.'; echo '.'; echo '.')|pwd=1234567890 $openssl req -new $configfile -key $instancedir/etc/openxpki/ca/testdummyca1/cakey.pem -passin env:pwd -out $instancedir/csr.pem`;  
    if ($CHILD_ERROR) {
        diag "Could not generate CA CSR";
        return 0;
    }
    
    `mkdir $instancedir/demoCA`;
    `touch $instancedir/demoCA/index.txt`;
    `echo 01 > $instancedir/demoCA/serial`;

    `cd $instancedir; pwd=1234567890 $openssl ca -selfsign $configfile -in csr.pem -keyfile etc/openxpki/ca/testdummyca1/cakey.pem -passin env:pwd -utf8 -outdir . -policy policy_anything -batch -extensions v3_ca -preserveDN -out cacert.pem`;
    if ($CHILD_ERROR) {
        diag "Could not issue CA certificate";
        return 0;
    }

    open CACERT_IN,  '<', "$instancedir/cacert.pem";
    open CACERT_OUT, '>', "$instancedir/etc/openxpki/ca/testdummyca1/cert.pem";
    my $cert;
    while (<CACERT_IN>) {
        if ($_ =~ m{ \A -----BEGIN }xms) {
            $cert = 1;
        }
        next if (! $cert);
        print CACERT_OUT $_;
    }
    close CACERT_IN;
    close CACERT_OUT;

    my $identifier = `$openxpkiadm certificate import --config $instancedir/etc/openxpki/config.xml --file $instancedir/etc/openxpki/ca/testdummyca1/cert.pem|tail -1|sed -e 's/  Identifier: //'`;
    if ($CHILD_ERROR || ! $identifier) {
        diag "Could not import CA cert into DB";
        return 0;
    }
    `$openxpkiadm certificate alias --config $instancedir/etc/openxpki/config.xml -realm I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA --alias testdummyca1 --identifier $identifier`;
    if ($CHILD_ERROR) {
        diag "Could not create alias for certificate";
        return 0;
    }
    open PATCH, "|patch -p0";
    print PATCH << "XEOF";
--- $instancedir/etc/openxpki/config.xml  2006-12-04 10:41:16.000000000 +0100
+++ $instancedir/etc/openxpki/config.xml  2006-12-04 10:49:32.000000000 +0100
@@ -46,8 +46,8 @@
 
       <secret>
         <group id="default" label="I18N_OPENXPKI_CONFIG_DEFAULT_SECRET_AUTHENTICATION_GROUP">
-          <method id="plain">
-            <total_shares>1</total_shares>
+          <method id="literal">
+            <value>1234567890</value>
           </method>
           <cache>
             <type>daemon</type>
XEOF
    close PATCH;
    if ($CHILD_ERROR) {
        diag "Could not patch file";
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

    # TODO
    # if this is uncommented, prove hangs on t/60_workflow/09_deploy_and_start_testserver - !???
    # uncommented for now, the information is not that important anyways
    # (it is the STDERR output before the stderr is redirect, this is
    # only interesting if the server does not start, but this can and should
    # be investigated manually anyways ...)
    # 
    #if ($ENV{DEBUG}) {
    #    $stderr = '';
    #}

    my $args = '';
    if ($arg_ref->{FOREGROUND}) {
        $args = '--foreground';
    }
    if ($ENV{DEBUG}) {
        $args .= ' --debug 128 ';
    }

    my $openxpkictl = "openxpkictl";
    if ($ENV{DEPLOYMENT_PREFIX} && -e $ENV{DEPLOYMENT_PREFIX}."/$openxpkictl" && -x _) {
        $openxpkictl = $ENV{DEPLOYMENT_PREFIX}."/$openxpkictl"; 
        diag "Using openxpkictl: $openxpkictl\n ";
    }

    return ! system("$openxpkictl --config $configfile $args start $stderr");
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

=head2 create_ca_cert

Creates a CA certificate using OpenSSL for installation in a freshly
deployed test server. Takes a named argument of 'DIRECTORY', which is
the directory of the deployed server.
Also imports the certificate into the OpenXPKI database and creates an
appropriate alias for it. Then patches the config file to use the
literal password for the key. This enables you to start a test server
with a working CA certificate using start_test_server().

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
