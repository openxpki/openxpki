package OpenXPKI::SOAP;

use strict;
use warnings;
use English;
use Config::Std;
use Data::Dumper;
use SOAP::Transport::HTTP;
#use SOAP::Transport::HTTP2; # Please adjust contructor call below, if you switch this!

use OpenXPKI::Log4perl;

my $configfile = $ENV{OPENXPKI_SOAP_CONFIG_FILE} || '/etc/openxpki/soap/default.conf';

my $config;
if (! read_config $configfile, $config) {
    die "Could not open SOAP interface config file $configfile";
}

my $log_config = $config->{global}->{log_config};
if (! $log_config) {
    die "Could not get Log4perl configuration file from config file";
}

my $facility = $config->{global}->{log_facility};
if (! $facility) {
    die "Could not get Log4perl logging facility from config file";
}


OpenXPKI::Log4perl->init_or_fallback( $log_config );

my $log = Log::Log4perl->get_logger($facility);

$log->info("SOAP handler initialized from config file $configfile");

my @soap_modules;
foreach my $key (keys %{$config}) {
    if ($key =~ /(OpenXPKI::SOAP::[:\w\d]+)/) {
        push @soap_modules, $1;
    }
}

$log->debug('Modules loaded: ' . join(", ", @soap_modules));

sub handler {

    #warn "Entered OpenXPKI::Server::SOAP::handler";
    my $oSoapHandler = SOAP::Transport::HTTP::CGI
        ->dispatch_to( @soap_modules )->handle;
}

1;
