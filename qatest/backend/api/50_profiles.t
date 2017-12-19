
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
use lib "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 43;


# Init server
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( SampleConfig Server Workflows WorkflowCreateCert ) ],
    add_config => {
        "realm.ca-one.profile.I18N_OPENXPKI_PROFILE_USER_HIDDEN" => {
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

# Init client
my $client = $oxitest->new_client_tester;
$client->connect;
$client->init_session;
$client->login("caop");

my $result;

#
# get_cert_profiles
#
$result = $client->send_command_ok('get_cert_profiles');
cmp_deeply $result, superhashof({
    map {
        $_ => { label => ignore(), value => ignore() }
    }
    qw(
        I18N_OPENXPKI_PROFILE_TLS_CLIENT
        I18N_OPENXPKI_PROFILE_TLS_SERVER
        I18N_OPENXPKI_PROFILE_USER
    )
}), "list profiles";

$result = $client->send_command_ok('get_cert_profiles' => { NOHIDE => 1 });
cmp_deeply $result, superhashof({
    map {
        $_ => { label => ignore(), value => ignore() }
    }
    qw(
        I18N_OPENXPKI_PROFILE_TLS_CLIENT
        I18N_OPENXPKI_PROFILE_TLS_SERVER
        I18N_OPENXPKI_PROFILE_USER
        I18N_OPENXPKI_PROFILE_USER_HIDDEN
    )
}), "list profiles incl. hidden ones (without any UI definition)";

#
# list_used_profiles
#
$oxitest->create_cert(
    profile => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
    hostname => "127.0.0.1",
);
$oxitest->create_cert(
    profile => "I18N_OPENXPKI_PROFILE_TLS_CLIENT",
    hostname => "127.0.0.1",
    application_name => "Joust",
);
$result = $client->send_command_ok('list_used_profiles');
cmp_deeply $result, superbagof(
    map {
        superhashof( { value => $_ } )
    }
    qw(
        I18N_OPENXPKI_PROFILE_TLS_SERVER
        I18N_OPENXPKI_PROFILE_TLS_CLIENT
    )
), "Show expected profiles";

#
# get_cert_subject_profiles
#
$result = $client->send_command_ok('get_cert_subject_profiles' => {
    PROFILE => 'I18N_OPENXPKI_PROFILE_TLS_SERVER'
});
cmp_deeply $result, superhashof({
    map {
        $_ => superhashof({ LABEL => ignore() })
    }
    qw(
        00_basic_style
        05_advanced_style
    )
}), "list profile styles";

$result = $client->send_command_ok('get_cert_subject_profiles' => {
    PROFILE => 'I18N_OPENXPKI_PROFILE_TLS_SERVER',
    NOHIDE => 1,
});
cmp_deeply $result, superhashof({
    map {
        $_ => superhashof({ LABEL => ignore() })
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
$result = $client->send_command_ok('get_cert_subject_styles' => {
    PROFILE => 'I18N_OPENXPKI_PROFILE_TLS_SERVER'
});
cmp_deeply $result, superhashof({
    map {
        $_ => superhashof({
            LABEL => ignore(),
            ADDITIONAL_INFORMATION => { INPUT => ignore() },
            DN => ignore(),
            TEMPLATE => ignore(),
        })
    }
    qw(
        00_basic_style
        05_advanced_style
    )
}), "list profile style details";

#
# list_supported_san
#
$result = $client->send_command_ok('list_supported_san');
cmp_deeply [ values %$result ], superbagof(qw( email URI DNS RID IP dirName otherName GUID UPN )),
    "list supported certificate SAN fields";

#
# get_field_definition
#
$result = $client->send_command_ok('get_field_definition' => {
    PROFILE => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
    STYLE => "00_basic_style",
    # default SECTION = "subject"
});
cmp_deeply $result, superbagof(
    map {
        superhashof({
            ID => $_,
            TYPE => ignore(),
        })
    }
    qw(
        hostname
        hostname2
        port
    )
), "list field definitions (I18N_OPENXPKI_PROFILE_TLS_SERVER.style.00_basic_style.ui.subject)";

$result = $client->send_command_ok('get_field_definition' => {
    PROFILE => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
    STYLE => "00_basic_style",
    SECTION => "info",
});
cmp_deeply $result, superbagof(
    map {
        superhashof({
            ID => $_,
            TYPE => ignore(),
        })
    }
    qw(
        requestor_gname
        requestor_name
        requestor_email
        requestor_affiliation
        comment
    )
), "list field definitions (I18N_OPENXPKI_PROFILE_TLS_SERVER.style.00_basic_style.ui.info)";

#
# get_additional_information_fields
#
$result = $client->send_command_ok('get_additional_information_fields');
cmp_deeply $result, { ALL => {
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
} }, "list all additional information fields";

#
# get_key_algs
#
$result = $client->send_command_ok('get_key_algs' => {
    PROFILE => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
});
cmp_deeply $result, bag( qw( dsa rsa ec ) ), "list key algorithms";

#
# get_key_algs
#
$result = $client->send_command_ok('get_key_enc' => {
    PROFILE => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
});
cmp_deeply $result, bag( qw( aes256 idea ) ), "list key encryption algorithms";

$result = $client->send_command_ok('get_key_enc' => {
    PROFILE => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
    NOHIDE => 1,
});
cmp_deeply $result, bag( qw( aes256 idea 3des ) ), "list key encryption algorithms (including hidden)";

#
# get_key_params
#
$result = $client->send_command_ok('get_key_params' => {
    PROFILE => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
});
cmp_deeply $result, bag( qw( key_length curve_name ) ), "list key parameters (all)";

$result = $client->send_command_ok('get_key_params' => {
    PROFILE => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
    ALG => 'rsa',
});
cmp_deeply $result, {
    key_length => bag( qw( 2048 4096 ) ),
}, "list key parameters for RSA";

$result = $client->send_command_ok('get_key_params' => {
    PROFILE => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
    ALG => 'rsa',
    NOHIDE => 1,
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
};
$result = $client->send_command_ok('render_subject_from_template' => {
    PROFILE => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
    VARS => $vars,
});
like $result, qr/ CN=james:333 /msxi, "render cert subject";

#
# render_san_from_template
#
$result = $client->send_command_ok('render_san_from_template' => {
    PROFILE => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
    VARS => $vars,
    ADDITIONAL => { dNs => [ "george" ] }, # dNs should be converted to DNS
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
$result = $client->send_command_ok('render_metadata_from_template' => {
    PROFILE => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
    VARS => $vars,
});
cmp_deeply $result, {
    requestor => sprintf("%s %s", $vars->{requestor_gname}, $vars->{requestor_name}),
    email => $vars->{requestor_email},
    entity => $vars->{hostname},
}, "render cert subject";

1;
