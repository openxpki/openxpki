#!/usr/bin/perl

use strict;
use warnings;

use CGI qw( -debug );
use CGI::Carp qw( fatalsToBrowser );
use CGI::Fast;
use Data::Dumper;
use English;

use JSON;
use MIME::Base64;
use NetAddr::IP;
use OpenXPKI::Exception;
use OpenXPKI::Client::SCEP;
use OpenXPKI::Client::Config;
use OpenXPKI::Serialization::Simple;

use Log::Log4perl;

our $config = OpenXPKI::Client::Config->new('scep');
my $log = $config->logger();

$log->info("SCEP handler initialized");

my $json = new JSON();

while (my $cgi = CGI::Fast->new()) {

    my $conf = $config->config();

    my $socket  = $conf->{global}->{socket};
    my $realm   = $conf->{global}->{realm};
    my $iprange = $conf->{global}->{iprange};
    my $profile = $conf->{global}->{profile};
    my $server  = $conf->{global}->{servername};
    my $enc_alg = $conf->{global}->{encryption_algorithm};
    my $hash_alg = $conf->{global}->{hash_algorithm};

    my $log = $config->logger();

    # the allowed IP range from the config file
    my $allowed_range = new NetAddr::IP $iprange;

    my $requesting_host = new NetAddr::IP $ENV{'REMOTE_ADDR'}; # the host

    # Check if requesting host is allowed to talk to us
    if (!$requesting_host->within($allowed_range)) {
        # TODO: better response?

        print $cgi->header(
           -type => 'text/plain',
           -status => '403 Access denied'
        );

        print "Access to this service was denied by configuration.";

        $log->error("Unauthorized access from $requesting_host");
        next;
    }

    # Fetch SCEP message from CGI (cf. Section 3.1 of the SCEP draft)
    # http://www.ietf.org/internet-drafts/draft-nourse-scep-13.txt
    my $operation = $cgi->param('operation') || '';
    my $message   = $cgi->param('message') || '';

    # Get additional parameters from the url
    my @extra_params = $cgi->param();

    # TODO - Whitelist, Url-Decode?
    my $params = {};
    foreach my $param (@extra_params) {
        if ($param eq "operation" || $param eq "message") { next; }
        $params->{$param} = $cgi->param($param);
    }

    # Append the remote address to the params hash
    $params->{remote_addr} = $requesting_host->addr;

    $log->info('Incoming request from ' . $requesting_host->addr . ' with ' . $operation );

    # OpenXPKI::Client::SCEP does the actual work
    my $scep_client = OpenXPKI::Client::SCEP->new({
        SERVICE    => 'SCEP',
        REALM      => $realm,
        SOCKETFILE => $socket,
        TIMEOUT    => 120, # TODO - make configurable?
        PROFILE    => $profile,
        OPERATION  => $operation,
        MESSAGE    => $message,
        SERVER     => $server,
        ENCRYPTION_ALGORITHM => $enc_alg,
        HASH_ALGORITHM => $hash_alg
    });
    if (! defined $scep_client) {
        $log->error("Error creating SCEP Client instance!");
        die "Error creating SCEP Client instance!";
    }
    my $result = $scep_client->send_request($params);
    print $result;
    $log->debug('Response send');
}

=head1 Description

This file is the generic scep handler to be used as cgi script with your
favourite webserver (apache is tested, others are not but should work).
The script needs a config file which sets the parameters such as realm,
profile, workflow to be triggered on the OpenXPKI system on request.

To ease configuration, the script has an autodetexction feature for its
config file.

=head2 config file

The config file is parsed using Config::Std, all params are mandatory.

    [global]
    socket=/var/openxpki/openxpki.socket
    realm=ca-one
    iprange=0.0.0.0/0
    profile=I18N_OPENXPKI_PROFILE_TLS_SERVER
    servername=tls-scep-1
    encryption_algorithm=3DES

=over

=item socket

Location of the OpenXPKI socket file, the webserver needs rw access.

=item realm

The realm of the ca to be used.

=item iprange

Implements a simple ip based access control, the clients ip adress is checked
to be included in the given network. Only a single network definition is
supported, the default of 0.0.0.0/0 allows all ips to connect.

=item profile

The profile of the certificate to be requested, note that depending on the
backing workflow this might be ignored or overridden by other paramters.

=item servername

Path to the server side config of this scep service. Equal to the key from
the config section in the scep.yaml file.

=item encryption

Encrpytion to use, supported values are I<DES> and I<3DES>.

=back

=head2 config file location

=over

=item autodetected file

The default location for config files is /etc/openxpki/scep, the script
will use the filename of the called script (from ENV{SCRIPT_NAME)) and looks
for /etc/openxpki/scep/I<filename>.conf. If no file is found, the default
config is loaded from /etc/openxpki/scep/default.conf.
Note: The scriptname value respects symlinks, so you can use a single scep
handler script and create symlinks on it.

=item custom base directory

Set I<OPENXPKI_SCEP_CLIENT_CONF_DIR> to a directory path. The autodetection
will now use this path to find either the special or the default file. Note
that there is no fallback to the default location!

=item fixed file

Set I<OPENXPKI_SCEP_CLIENT_CONF_FILE> to an absolute file path.
On apache, this can be combined with location to set a config for a special
script:

   <Location /cgi-bin/scep/mailgateway>
      SetEnv OPENXPKI_SCEP_CLIENT_CONF_FILE /home/mailadm/scep.conf
   </Location>

=back

=head2 webserver setup

If you use apache, the easiest way is a directory based wildcard alias.

    ScriptAlias /scep  /usr/lib/cgi-bin/scep.fcgi
    <Directory "/usr/lib/cgi-bin/">
            AllowOverride None
            Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch
            Order allow,deny
            Allow from all
    </Directory>

Make your requests to C<http://server/scep/myserver> which will pull in
the config from /etc/openxpki/scep/myserver.conf.

Note: SCEP usually uses HTTP/1.0, so name based virtual hosts are not working.
