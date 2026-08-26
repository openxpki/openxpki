#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use FindBin qw( $Bin );

# CPAN modules
use Test::More;

# Project modules
use lib "$Bin/../lib", "$Bin/../../";
use OpenXPKI::Client::Simple;

plan tests => 5;

# The "envkeys" of a client based auth stack are resolved against this
# attribute. Inside the Mojolicious daemon %ENV holds only the SSL_CLIENT_*
# variables, so the per request environment has to be passed in explicitly.

my $passed = OpenXPKI::Client::Simple->new(
    config => { realm => 'democa' },
    env => {
        AUTHORIZE_SAMACCOUNTNAME => '_alice_anderson',
        SAML_TENANT => 'alice-t',
    },
);

is $passed->env->{AUTHORIZE_SAMACCOUNTNAME}, '_alice_anderson', 'username from passed environment';
is $passed->env->{SAML_TENANT}, 'alice-t', 'tenant from passed environment';

# CGI style callers do not pass anything and must keep seeing the process
# environment, where the webserver environment already is.
local $ENV{SAML_TENANT} = 'from-process-env';

my $default = OpenXPKI::Client::Simple->new( config => { realm => 'democa' } );

is $default->env->{SAML_TENANT}, 'from-process-env', 'default falls back to the process environment';
is $default->env, \%ENV, 'default is %ENV itself, not a copy';

# Two instances must not see each other's environment.
is $passed->env->{SAML_TENANT}, 'alice-t', 'passed environment is not overwritten by the process environment';
