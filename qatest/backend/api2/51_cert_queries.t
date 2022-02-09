#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 5;


#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( SampleConfig Workflows WorkflowCreateCert )],
    #log_level => 'trace',
);
my $cert = $oxitest->create_cert(
    profile => "tls_server",
    hostname => "fun",
    requestor_realname => 'Sarah Dessert',
    requestor_email => 'sahar@d-sert.d',
);
my $cert_id = $cert->{identifier};

#
# Tests
#

# certificate profile
lives_and {
    my $result = $oxitest->api2_command('get_profile_for_cert' => { identifier => $cert_id });
    is $result, "tls_server";
} "query certificate profile";

# possible certificate actions
lives_and {
    my $result = $oxitest->api2_command('get_cert_actions' => { identifier => $cert_id, role => "User" });
    cmp_deeply $result, superhashof({
        # actions are defined in config/config.d/realm/democa/uicontrol/_default.yaml,
        # they must exist and "User" must be defined in their "acl" section as creator
        workflow => superbagof(
            {
                'label' => 'I18N_OPENXPKI_UI_DOWNLOAD_PRIVATE_KEY',
                'workflow' => 'certificate_privkey_export',
            },
            {
                'label' => 'I18N_OPENXPKI_UI_CERT_ACTION_REVOKE',
                'workflow' => 'certificate_revocation_request_v2',
            },
        ),
    });
} "query actions for certificate (role 'User')";

# check certificate owner:
# the workflow automatically sets this to the workflow creator, which in our
# case is "raop" (see session user in OpenXPKI::Test::QA::Role::WorkflowCreateCert->create_cert)
lives_and {
    is $oxitest->api2_command('is_certificate_owner' => { identifier => $cert_id, user => "raop" }), 1;
} "confirm correct certificate owner";

lives_and {
    isnt $oxitest->api2_command('is_certificate_owner' => { identifier => $cert_id, user => "nerd" }), 1;
} "negate wrong certificate owner";
