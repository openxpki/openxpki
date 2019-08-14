#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;

# Project modules
use lib "$Bin/../../lib";
use lib "$Bin/../../../core/server";
use lib "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 22;


# Init server
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( SampleConfig Workflows WorkflowCreateCert ) ],
    add_config => {
        "realm.democa.profile.user_auth_enc_hidden" => {
            label => "Blah",
            style => {
                "00_user_basic_style" => {
                    label => "Blah",
                    description => "Blah",
                },
            },
        },
    },
);

my $result;

#
# get_cert_profiles
#
$result = $oxitest->api2_command("get_cert_profiles");
cmp_deeply $result, superhashof({
    map {
        $_ => { label => ignore(), value => ignore() }
    }
    qw(
        tls_client
        tls_server
        user_auth_enc
    )
}), "list profiles";

$result = $oxitest->api2_command("get_cert_profiles" => { showall => 1 });
cmp_deeply $result, superhashof({
    map {
        $_ => { label => ignore(), value => ignore() }
    }
    qw(
        tls_client
        tls_server
        user_auth_enc
        user_auth_enc_hidden
    )
}), "list profiles incl. hidden ones (without any UI definition)";

#
# list_used_profiles
#
$oxitest->create_cert(
    profile => "tls_server",
    hostname => "127.0.0.1",
);
$oxitest->create_cert(
    profile => "tls_client",
    hostname => "127.0.0.1",
    application_name => "Joust",
);
$result = $oxitest->api2_command("list_used_profiles");
cmp_deeply $result, superbagof(
    map {
        superhashof( { value => $_ } )
    }
    qw(
        tls_server
        tls_client
    )
), "Show expected profiles";

#
# get_cert_subject_profiles
#
$result = $oxitest->api2_command("get_cert_subject_profiles" => {
    profile => 'tls_server'
});
cmp_deeply $result, superhashof({
    map {
        $_ => superhashof({ label => ignore() })
    }
    qw(
        00_basic_style
        05_advanced_style
    )
}), "list profile styles";

$result = $oxitest->api2_command("get_cert_subject_profiles" => {
    profile => 'tls_server',
    showall => 1,
});
cmp_deeply $result, superhashof({
    map {
        $_ => superhashof({ label => ignore() })
    }
    qw(
        00_basic_style
        05_advanced_style
        enroll
    )
}), "list profile styles incl. hidden ones (without UI definition)";

#
# get_cert_subject_styles
#
$result = $oxitest->api2_command("get_cert_subject_styles" => {
    profile => 'tls_server'
});
cmp_deeply $result, superhashof({
    map {
        $_ => superhashof({
            label => ignore(),
            dn => ignore(),
            description => ignore(),
            subject_alternative_names => array_each(ignore()),
            additional_information => { input => ignore() },
            template => { input => ignore() },
        })
    }
    qw(
        00_basic_style
        05_advanced_style
        enroll
    )
}), "list profile style details" or diag explain $result;

#
# list_supported_san
#
$result = $oxitest->api2_command("list_supported_san");
cmp_deeply [ values %$result ], superbagof(qw( email URI DNS RID IP dirName otherName )),
    "list supported certificate SAN fields";

#
# get_field_definition
#
$result = $oxitest->api2_command("get_field_definition" => {
    profile => "tls_server",
    style => "00_basic_style",
    # default section = "subject"
});
cmp_deeply $result, superbagof(
    map {
        superhashof({
            id => $_,
            type => ignore(),
        })
    }
    qw(
        hostname
        hostname2
        port
    )
), "list field definitions (tls_server.style.00_basic_style.ui.subject)";

$result = $oxitest->api2_command("get_field_definition" => {
    profile => "tls_server",
    style => "00_basic_style",
    section => "info",
});
cmp_deeply $result, superbagof(
    map {
        superhashof({
            id => $_,
            type => ignore(),
        })
    }
    qw(
        requestor_gname
        requestor_name
        requestor_email
        requestor_affiliation
        comment
    )
), "list field definitions (tls_server.style.00_basic_style.ui.info)";

#
# get_additional_information_fields
#
$result = $oxitest->api2_command("get_additional_information_fields");
cmp_deeply $result, {
    map {
        $_ => ignore()
    }
    qw(
        requestor_gname
        requestor_name
        requestor_email
        requestor_affiliation
        comment
    )
}, "list all additional information fields";

#
# get_key_algs
#
$result = $oxitest->api2_command("get_key_algs" => {
    profile => "tls_server",
});
cmp_deeply $result, bag( qw( dsa rsa ec ) ), "list key algorithms";

#
# get_key_enc
#
$result = $oxitest->api2_command("get_key_enc" => {
    profile => "tls_server",
});
cmp_deeply $result, bag( qw( aes256 idea ) ), "list key encryption algorithms";

$result = $oxitest->api2_command("get_key_enc" => {
    profile => "tls_server",
    showall => 1,
});
cmp_deeply $result, bag( qw( aes256 idea 3des ) ), "list key encryption algorithms (including hidden)";

#
# get_key_params
#
$result = $oxitest->api2_command("get_key_params" => {
    profile => "tls_server",
});
cmp_deeply $result, bag( qw( key_length curve_name ) ), "list key parameters (all)";

$result = $oxitest->api2_command("get_key_params" => {
    profile => "tls_server",
    alg => 'rsa',
});
cmp_deeply $result, {
    key_length => bag( qw( 2048 4096 ) ),
}, "list key parameters for RSA";

$result = $oxitest->api2_command("get_key_params" => {
    profile => "tls_server",
    alg => 'rsa',
    showall => 1,
});
cmp_deeply $result, {
    key_length => bag( qw( 1024 2048 4096 ) ),
}, "list key parameters for RSA (including hidden)";

#
# render_subject_from_template
#
my $vars = {
    hostname => "james",
    hostname2 => [ "johann", "jo" ],
    port => 333,
    requestor_gname => "My",
    requestor_name  => "Self",
    requestor_email => 'my@self.me',
    # for 05_advanced_style:
    CN => "ACME",
    OU => "Goonies",
    DC => [ qw( example org ) ],
};
$result = $oxitest->api2_command("render_subject_from_template" => {
    profile => "tls_server",
    vars => $vars,
});
like $result, qr/ CN=james:333 /msxi, "render cert subject (default style)";

$result = $oxitest->api2_command("render_subject_from_template" => {
    profile => "tls_server",
    style => "05_advanced_style",
    vars => $vars,
});
like $result, qr/ CN=ACME .* OU=Goonies .* DC=example .* DC=org /msxi, "render cert subject (specified style)";

#
# render_san_from_template
#
$result = $oxitest->api2_command("render_san_from_template" => {
    profile => "tls_server",
    vars => $vars,
    additional => { dNs => [ "george" ] }, # dNs should be converted to DNS
});
cmp_deeply $result, bag(
    [ qw( DNS james) ],
    [ qw( DNS johann ) ],
    [ qw( DNS jo ) ],
    [ qw( DNS george ) ],
), "render cert subject alternative name";

#
# render_metadata_from_template
#
$result = $oxitest->api2_command("render_metadata_from_template" => {
    profile => "tls_server",
    vars => $vars,
});
cmp_deeply $result, {
    requestor => sprintf("%s %s", $vars->{requestor_gname}, $vars->{requestor_name}),
    email => $vars->{requestor_email},
    entity => $vars->{hostname},
}, "render cert metadata";

1;
