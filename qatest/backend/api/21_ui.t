#!/usr/bin/perl

# TODO Move this test to core/server/t/90_api using OpenXPKI::Test once setup_env() installs the default workflows
# See commented code at bottom for how to start

use strict;
use warnings;
use utf8;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use DateTime;
use Log::Log4perl qw(:easy);

# Project modules
use lib "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;
use OpenXPKI::Server::Context;
use OpenXPKI::Serialization::Simple;

plan tests => 8;


#
# Init helpers
#

# Import test certificates
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( SampleConfig Workflows WorkflowCreateCert Server ) ],
);

# Create test certificates
my $cert_info = $oxitest->create_cert(
    hostname        => "127.0.0.1",
    hostname2       => [ "127.0.0.2", "127.0.0.3" ],
    profile => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
);

# set user role to be allowed to create workflows etc.
$oxitest->session->data->role("CA Operator");

#
# Tests
#

# get_ui_system_status

lives_and {
    my $wftest = $oxitest->create_workflow(
        "certificate_revocation_request_v2" => {
            cert_identifier => $cert_info->{identifier},
            reason_code => 'keyCompromise',
            comment => 'Automated Test',
            invalidity_time => time(),
            flag_auto_approval => 1,
            flag_batch_mode => 1,
        }
    );

    # Go to pending
    $wftest->state_is('CHECK_FOR_REVOCATION');

    $wftest = $oxitest->create_workflow(
        "crl_issuance" => { force_issue => 1 }
    );

    $wftest->state_is('SUCCESS');
} 'Create workflow: auto-revoke certificate' or die "Creating workflow failed";

lives_and {
    my $data = $oxitest->api_command('get_ui_system_status', {});
    cmp_deeply $data, {
        crl_expiry =>       re(qr/^\d+$/),
        dv_expiry =>        re(qr/^\d+$/),
        secret_offline =>   re(qr/^[01]$/),
        version =>          re(qr/^[0-9\.]+$/),
        watchdog =>         re(qr/^\d+$/),
        worker =>           re(qr/^\d+$/),
        workflow =>         re(qr/^\d+$/),
        hostname =>         ignore(),
    };
} "get_ui_system_status";

# list_process

lives_and {
    my $data = $oxitest->api_command('list_process', {});
    cmp_deeply $data, array_each(
        {
            pid =>  re(qr/^\d+$/),
            time => re(qr/^\d+$/),
            info => re(qr/^.+$/),
        }
    );
} "list_process";

# get_menu

lives_and {
    my $refdata = $oxitest->get_config("realm.ca-one.uicontrol.CA Operator");
    my $data = $oxitest->api_command('get_menu', {});
    cmp_deeply $data, $refdata;
} "get_menu";

# get_motd

lives_and {
    $oxitest->api_command(set_data_pool_entry => {
        NAMESPACE   => 'webui.motd',
        KEY         => '_any',
        VALUE       => OpenXPKI::Serialization::Simple->new->serialize('rotflbtc'),
    });

    my $data = $oxitest->api_command('get_motd', {});
    is $data, 'rotflbtc';
} "get_motd";

# render_template

lives_and {
    my $data = $oxitest->api_command('render_template', {
        TEMPLATE => "[% animal %] does [% sound %]",
        PARAMS => { animal => "rabbit", sound => "meditate" }
    });
    is $data, 'rabbit does meditate';
} "render_template";
