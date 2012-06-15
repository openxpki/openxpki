## OpenXPKI::Client::HTML::SC::Dispatcher
##
## Written by Arkadius Litwinczuk 2010
## Copyright (C) 2010 by The OpenXPKI Project

package OpenXPKI::Client::HTML::SC::Dispatcher;

use strict;

#use Apache2;
use base qw ( Apache2::Controller::Dispatch::Simple );

#use OpenXPKI::Client::HTML::SCB::Dispatch;
use Config::Std;
use Exporter;

our @EXPORT_OK = qw( config );

# read configuration only Once when the dispatcher gets called after a HTTP Request
my %config;
read_config(
    '/etc/openxpki/sc_frontend.cfg' =>
        %config );

sub config {
    return \%config;
}


# Dispatch Map implemented for usage by the Apache2Controller base class 
sub dispatch_map {
    return {
        #'index'           => 'OpenXPKI::Client::HTML::SC::Main',
        'pinreset'        => 'OpenXPKI::Client::HTML::SC::Pinreset',
        'personalization' => 'OpenXPKI::Client::HTML::SC::Personalization',
        'utilities'       => 'OpenXPKI::Client::HTML::SC::Utilities',
        'getauthcode'     => 'OpenXPKI::Client::HTML::SC::Getauthcode',
        'changepolicy'     => 'OpenXPKI::Client::HTML::SC::Changecardpolicy',
    #    'dev'             => 'OpenXPKI::Client::HTML::SC::APITest',
     #   'language'     => 'OpenXPKI::Client::HTML::SC::Language',
    };
}

1;
