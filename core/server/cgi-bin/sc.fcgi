#!/usr/bin/perl -w

# Wrapper for the Smarcard Frontend Handler

use CGI;
use CGI::Fast;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser);
use JSON;
use English;
use strict;
use warnings;
use Data::Dumper;
use Config::Std;
use OpenXPKI::Log4perl;
use OpenXPKI::i18n qw( i18nGettext set_language set_locale_prefix );
use OpenXPKI::Client::SC;
use OpenXPKI::Client::Config;

our $config = OpenXPKI::Client::Config->new('sc');
my $conf = $config->default();
my $log = $config->logger();

$log->info("SmartCard handler initialized, " . $$ );

my $locale_directory = $conf->{global}->{locale_directory} || '/usr/share/locale';
my $default_language = $conf->{global}->{default_language} || 'en_US';

set_locale_prefix ($locale_directory);
set_language      ($default_language);

my %card_config = %{$conf};
delete $card_config{realm};

my @header_tpl;
foreach my $key (keys (%{$conf->{header}})) {
    my $val = $conf->{header}->{$key};
    $key =~ s/-/_/g;
    push @header_tpl, ("-$key", $val);
}

$log->info('Start fcgi loop ' . $$);

while (my $cgi = CGI::Fast->new()) {

    my $sess_id = $cgi->cookie('oxisess-sc') || undef;
    my $session_front = new CGI::Session(undef, $sess_id, {Directory=>'/tmp'});
    $log->debug('session id (front) is '. $session_front->id);

    our $cookie = {
        -name => 'oxisess-sc',
        -value => $session_front->id,
        -Secure => ($ENV{'HTTPS'} ? 1 : 0),
        -HttpOnly => 1
    };
    our @header = @header_tpl;
    push @header, ('-cookie', $cgi->cookie( $cookie ));
    push @header, ('-type','application/json; charset=UTF-8');

    my %global = %{$conf->{global}};
    my %auth   = %{$conf->{auth}};

    $log->trace('Global ' . Dumper \%global );
    $log->trace('Auth ' . Dumper \%auth );

    my $client = OpenXPKI::Client::SC->new({
        session => $session_front,
        logger => $log,
        config => \%global,
        card_config => \%card_config,
        auth => \%auth
    });

    my $result = $client->handle_request({ cgi => $cgi });
    if ($result) {
        $result->render();
    }

}

$log->info('end fcgi loop ' . $$);
