package OpenXPKI::Test::Role::TestRealms;
use Moose::Role;

=head1 NAME

OpenXPKI::Test::Role::TestRealms - Moose role that extends L<OpenXPKI::Test>
with test realms 'alpha', 'beta' and 'gamma'

=head1 DESCRIPTION

=cut

# Core modules

# CPAN modules

# Project modules

requires "config_writer";
requires "password_hash";
requires "testenv_root";


before 'init_user_config' => sub { # ... so we do not overwrite user supplied configs
    my $self = shift;

    # sample realms
    for my $realm (qw( alpha beta gamma )) {
        $self->config_writer->add_user_config(
            "realm.$realm" => {
                "auth" => $self->_auth,
                "crypto" => $self->_crypto($realm),
                "workflow" => {
                    "persister" => $self->_workflow_persister,
                    # OpenXPKI::Workflow::Handler checks existance of workflow.def
                    "def" => { "empty" => { state => { INITIAL => { } } } },
                },
                # certificate profiles
                "profile" => {
                    "default"                           => $self->_profile_default,
                    "template"                          => $self->_cert_profile_template,
                    "I18N_OPENXPKI_PROFILE_TLS_CLIENT"  => $self->_cert_profile_client,
                    "I18N_OPENXPKI_PROFILE_TLS_SERVER"  => $self->_cert_profile_server,
                    "I18N_OPENXPKI_PROFILE_USER"        => $self->_cert_profile_user,
                },
                # CRL
                "crl" => { "default" => $self->_crl_default },
            },
        );
        $self->config_writer->add_user_config(
            "system.realms.$realm" => $self->_system_realm($realm)
        );
    }
};

sub _auth {
    my ($self) = @_;
    return {
        stack => {
            _System    => {
                description => "System",
                handler => "System",
            },
            Anonymous => {
                description => "Anonymous",
                handler => "Anonymous",
            },
            Test => {
                description => "OpenXPKI test auth stack",
                handler => "OxiTest",
            },
        },
        handler => {
            "System" => {
                type => "Anonymous",
                label => "System",
                role => "System",
            },
            "Anonymous" => {
                type => "Anonymous",
                label => "System",
            },
            "OxiTest" => {
                label => "OpenXPKI Test Authentication Handler",
                type  => "Password",
                user  => {
                    # password is always "openxpki"
                    caop => {
                        digest => $self->password_hash, # "{ssha}JQ2BAoHQZQgecmNjGF143k4U2st6bE5B",
                        role   => "CA Operator",
                    },
                    raop => {
                        digest => $self->password_hash,
                        role   => "RA Operator",
                    },
                    raop2 => {
                        digest => $self->password_hash,
                        role   => "RA Operator",
                    },
                    user => {
                        digest => $self->password_hash,
                        role   => "User"
                    },
                    user2 => {
                        digest => $self->password_hash,
                        role   => "User"
                    },
                },
            },
        },
        roles => {
            "Anonymous"   => { label => "Anonymous" },
            "CA Operator" => { label => "CA Operator" },
            "RA Operator" => { label => "RA Operator" },
            "SmartCard"   => { label => "SmartCard" },
            "System"      => { label => "System" },
            "User"        => { label => "User" },
        },
    };
}

sub _crypto {
    my ($self, $realm) = @_;
    return {
        type => {
            certsign    => "$realm-signer",
            datasafe    => "$realm-datavault",
            scep        => "$realm-scep",
        },
        # The actual token setup, based on current token.xml
        token => {
            default => {
                backend => "OpenXPKI::Crypto::Backend::OpenSSL",

                # Template to create key, available vars are
                # ALIAS (ca-one-signer-1), GROUP (ca-one-signer), GENERATION (1)
                key => $self->config_writer->get_private_key_path($realm, "[% ALIAS %]"),

                # possible values are OpenSSL, nCipher, LunaCA
                engine => "OpenSSL",
                engine_section => '',
                engine_usage => '',
                key_store => "OPENXPKI",

                # OpenSSL binary location
                shell => $self->config_writer->path_openssl,

                # OpenSSL binary call gets wrapped with this command
                wrapper => '',

                # random file to use for OpenSSL
                randfile => $self->testenv_root."/var/openxpki/rand",

                # Default value for import, recorded in database, can be overriden
                secret => "default",
            },
            "$realm-signer" => {
                inherit => "default",
            },
            "$realm-datavault" => {
                inherit => "default",
            },
            "$realm-scep" => {
                inherit => "default",
                backend => "OpenXPKI::Crypto::Tool::SCEP",
                shell => $self->config_writer->path_openca_scep,
            },
            # A different scep token for another scep server
            "$realm-special-scep" => {
                inherit => "$realm-scep",
            },
        },
        # Define the secret groups
        secret => {
            default => {
                label => "Default secret group of this realm",
                export => 0,
                method => "literal",
                value => "root",
                cache => "daemon",
            },
        },
    };
}

sub _workflow_persister {
    my ($self) = @_;
    return {
        OpenXPKI => {
            class           => "OpenXPKI::Server::Workflow::Persister::DBI",
            workflow_table  => "WORKFLOW",
            history_table   => "WORKFLOW_HISTORY",
        },
        Volatile => {
            class           => "OpenXPKI::Server::Workflow::Persister::Null",
        },
    };
}

sub _profile_default {
    return {
        digest     => "sha256",
        extensions => {
            authority_info_access => {
                ca_issuers => "http://localhost/cacert.crt",
                critical   => 0,
                ocsp       => "http://ocsp.openxpki.org/",
            },
            authority_key_identifier =>
                { critical => 0, issuer => 1, keyid => 1 },
            basic_constraints => { ca => 0, critical => 1 },
            copy              => "copy",
            cps => { critical => 0, uri => "http://localhost/cps.html" },
            crl_distribution_points => {
                critical => 0,
                uri      => [
                    "http://localhost/crl/[% ISSUER.CN.0 %].pem",
                    "ldap://localhost/[% ISSUER.DN %]",
                ],
            },
            issuer_alt_name => { copy => 1, critical => 0 },
            netscape        => {
                cdp => {
                    ca_uri   => "http://localhost/cacrl.crt",
                    critical => 0,
                    uri      => "http://localhost/cacrl.crt",
                },
                certificate_type => {
                    critical          => 0,
                    object_signing    => 0,
                    object_signing_ca => 0,
                    smime_client      => 0,
                    smime_client_ca   => 0,
                    ssl_client        => 0,
                    ssl_client_ca     => 0,
                },
                comment => {
                    critical => 0,
                    text =>
                        "This is a generic certificate. Generated with OpenXPKI trustcenter software.",
                },
            },
            policy_identifier      => { critical => 0, oid  => "1.2.3.4" },
            subject_key_identifier => { critical => 0, hash => 1 },
        },
        increasing_serials => 1,
        key                => {
            alg => [ "rsa", "ec", "dsa" ],
            dsa => { key_length => [ 2048, 4096 ] },
            ec  => {
                curve_name =>
                    [ "prime192v1", "c2tnb191v1", "prime239v1", "sect571r1" ],
                key_length => [ "_192", "_256" ],
            },
            enc      => [ "aes256", "_3des", "idea" ],
            generate => "both",
            rsa => { key_length => [ 2048, 4096, "_1024" ] },
        },
        publish                 => [ "queue", "disk" ],
        randomized_serial_bytes => 8,
        validity => { notafter => "+01" },
    };
}

sub _cert_profile_template {
    return {
        application_name => {
            description => "I18N_OPENXPKI_UI_PROFILE_APPLICATION_NAME_DESC",
            id          => "application_name",
            label       => "I18N_OPENXPKI_UI_PROFILE_APPLICATION_NAME",
            option      => [ "scep", "soap", "generic" ],
            preset      => "[% CN.0.replace('^[^:]+:?','') %]",
            type        => "select",
            width       => 20,
        },
        c => {
            description => "I18N_OPENXPKI_UI_PROFILE_C_DESC",
            id          => "C",
            label       => "C",
            min         => 0,
            preset      => "C",
            type        => "freetext",
            width       => 2,
        },
        cn => {
            description => "I18N_OPENXPKI_UI_PROFILE_CN_DESC",
            id          => "CN",
            label       => "CN",
            preset      => "CN",
            type        => "freetext",
            width       => 60,
        },
        comment => {
            description => "I18N_OPENXPKI_UI_PROFILE_COMMENT_DESC",
            height      => 10,
            id          => "comment",
            label       => "I18N_OPENXPKI_UI_PROFILE_COMMENT",
            min         => 0,
            type        => "textarea",
            width       => 40,
        },
        dc => {
            description => "I18N_OPENXPKI_UI_PROFILE_DC_DESC",
            id          => "DC",
            label       => "DC",
            max         => 1000,
            min         => 0,
            preset      => "DC.X",
            type        => "freetext",
            width       => 40,
        },
        department => {
            description => "I18N_OPENXPKI_UI_PROFILE_DEPARTMENT_DESC",
            id          => "department",
            label       => "I18N_OPENXPKI_UI_PROFILE_DEPARTMENT",
            match       => ".+",
            type        => "freetext",
            width       => 60,
        },
        email => {
            description => "I18N_OPENXPKI_UI_PROFILE_EMAILADDRESS_DESC",
            id          => "email",
            label       => "I18N_OPENXPKI_UI_PROFILE_EMAILADDRESS",
            match       => ".+\@.+",
            type        => "freetext",
            width       => 30,
        },
        hostname => {
            default     => "fully.qualified.example.com",
            description => "I18N_OPENXPKI_UI_PROFILE_HOSTNAME_DESC",
            id          => "hostname",
            label       => "I18N_OPENXPKI_UI_PROFILE_HOSTNAME",
            match =>
                "\\A [a-zA-Z0-9] [a-zA-Z0-9-]* (\\.[a-zA-Z0-9-]*[a-zA-Z0-9])* \\z",
            preset => "[% CN.0.replace(':.*','') %]",
            type   => "freetext",
            width  => 60,
        },
        hostname2 => {
            default     => "fully.qualified.example.com",
            description => "I18N_OPENXPKI_UI_PROFILE_EXTRA_HOSTNAME_DESC",
            id          => "hostname2",
            label       => "I18N_OPENXPKI_UI_PROFILE_EXTRA_HOSTNAME",
            match =>
                "\\A [a-zA-Z0-9] [a-zA-Z0-9-]* (\\.[a-zA-Z0-9-]*[a-zA-Z0-9])* \\z",
            max    => 100,
            min    => 0,
            preset => "SAN_DNS.X",
            type   => "freetext",
            width  => 60,
        },
        o => {
            description => "I18N_OPENXPKI_UI_PROFILE_O_DESC",
            id          => "O",
            label       => "O",
            preset      => "O",
            type        => "freetext",
            width       => 40,
        },
        ou => {
            description => "I18N_OPENXPKI_UI_PROFILE_OU_DESC",
            id          => "OU",
            label       => "OU",
            max         => 1000,
            min         => 0,
            preset      => "OU.X",
            type        => "freetext",
            width       => 40,
        },
        port => {
            description => "I18N_OPENXPKI_UI_PROFILE_PORT_DESC",
            id          => "port",
            label       => "I18N_OPENXPKI_UI_PROFILE_PORT",
            match       => "\\A \\d+ \\z",
            min         => 0,
            preset =>
                "[% CN.0.replace('^[^:]+(:([0-9]+))?','\$2').replace('[^0-9]+','') %]",
            type  => "freetext",
            width => 5,
        },
        realname => {
            description => "I18N_OPENXPKI_UI_PROFILE_REALNAME_DESC",
            id          => "realname",
            label       => "I18N_OPENXPKI_UI_PROFILE_REALNAME",
            match       => ".+",
            type        => "freetext",
            width       => 40,
        },
        requestor_affiliation => {
            description =>
                "I18N_OPENXPKI_UI_PROFILE_REQUESTOR_AFFILIATION_DESC",
            id     => "requestor_affiliation",
            label  => "I18N_OPENXPKI_UI_PROFILE_REQUESTOR_AFFILIATION",
            option => [ "System Owner", "System Admin", "Other" ],
            type   => "select",
            width  => 20,
        },
        requestor_email => {
            description => "I18N_OPENXPKI_UI_PROFILE_REQUESTOR_EMAIL_DESC",
            id          => "requestor_email",
            label       => "I18N_OPENXPKI_UI_PROFILE_REQUESTOR_EMAIL",
            match       => ".+\@.+",
            type        => "freetext",
            width       => 40,
        },
        requestor_gname => {
            description =>
                "I18N_OPENXPKI_UI_PROFILE_REQUESTOR_FIRSTNAME_DESC",
            id    => "requestor_gname",
            label => "I18N_OPENXPKI_UI_PROFILE_REQUESTOR_FIRSTNAME",
            type  => "freetext",
            width => 40,
        },
        requestor_name => {
            description => "I18N_OPENXPKI_UI_PROFILE_REQUESTOR_LASTNAME_DESC",
            id          => "requestor_name",
            label       => "I18N_OPENXPKI_UI_PROFILE_REQUESTOR_LASTNAME",
            type        => "freetext",
            width       => 40,
        },
        requestor_phone => {
            description => "I18N_OPENXPKI_UI_PROFILE_PHONE_DESC",
            id          => "requestor_phone",
            label       => "I18N_OPENXPKI_UI_PROFILE_PHONE",
            type        => "freetext",
            width       => 20,
        },
        sample => {
            description => "I18N_OPENXPKI_UI_PROFILE_O_DESC",
            height      => 10,
            id          => "smpl",
            label       => "O",
            match       => "\\A [A-Za-z\\d\\-\\.]+ \\z",
            max         => 1,
            min         => 1,
            type        => "freetext",
            width       => 40,
        },
        san_dns => {
            description => "I18N_OPENXPKI_UI_PROFILE_SAN_DNS_DESCRIPTION",
            id          => "dns",
            label       => "I18N_OPENXPKI_UI_PROFILE_SAN_DNS",
            match =>
                "\\A [a-zA-Z0-9] [a-zA-Z0-9-]* (\\.[a-zA-Z0-9-]*[a-zA-Z0-9])* \\z",
            max   => 20,
            min   => 0,
            type  => "freetext",
            width => 40,
        },
        san_guid => {
            description => "I18N_OPENXPKI_UI_PROFILE_SAN_GUID_DESCRIPTION",
            id          => "guid",
            label       => "I18N_OPENXPKI_UI_PROFILE_SAN_GUID",
            max         => 20,
            min         => 0,
            type        => "freetext",
            width       => 40,
        },
        san_ipv4 => {
            description => "I18N_OPENXPKI_UI_PROFILE_SAN_IP_DESCRIPTION",
            id          => "ip",
            label       => "I18N_OPENXPKI_UI_PROFILE_SAN_IP",
            match =>
                "\\A ((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?) \\z",
            max   => 20,
            min   => 0,
            type  => "freetext",
            width => 40,
        },
        san_rid => {
            description => "I18N_OPENXPKI_UI_PROFILE_SAN_RID_DESCRIPTION",
            id          => "rid",
            label       => "I18N_OPENXPKI_UI_PROFILE_SAN_RID",
            max         => 20,
            min         => 0,
            type        => "freetext",
            width       => 40,
        },
        san_upn => {
            description => "I18N_OPENXPKI_UI_PROFILE_SAN_UPN_DESCRIPTION",
            id          => "upn",
            label       => "I18N_OPENXPKI_UI_PROFILE_SAN_UPN",
            max         => 20,
            min         => 0,
            type        => "freetext",
            width       => 40,
        },
        san_uri => {
            description => "I18N_OPENXPKI_UI_PROFILE_SAN_URI_DESCRIPTION",
            id          => "uri",
            label       => "I18N_OPENXPKI_UI_PROFILE_SAN_URI",
            max         => 20,
            min         => 0,
            type        => "freetext",
            width       => 40,
        },
        userid => {
            default     => 12345,
            description => "I18N_OPENXPKI_UI_PROFILE_USERID_DESC",
            id          => "userid",
            label       => "I18N_OPENXPKI_UI_PROFILE_USERID",
            match       => "\\A [0-9]+ \\z",
            type        => "freetext",
            width       => 40,
        },
        username => {
            default     => "testuser",
            description => "I18N_OPENXPKI_UI_PROFILE_USERNAME_DESC",
            id          => "username",
            label       => "I18N_OPENXPKI_UI_PROFILE_USERNAME",
            match       => "\\A [A-Za-z0-9\\.]+ \\z",
            type        => "freetext",
            width       => 20,
        },
    };
}

sub _cert_profile_client {
    return {
        label => "I18N_OPENXPKI_UI_PROFILE_TLS_CLIENT_LABEL",
        style => {
            "00_basic_style" => {
                description =>
                    "I18N_OPENXPKI_UI_PROFILE_TLS_CLIENT_BASIC_DESC",
                label    => "I18N_OPENXPKI_UI_PROFILE_TLS_CLIENT_BASIC_LABEL",
                metadata => {
                    email     => "[% requestor_email %]",
                    entity    => "[% hostname FILTER lower %]",
                    requestor => "[% requestor_gname %] [% requestor_name %]",
                },
                subject => {
                    dn =>
                        "CN=[% hostname %]:[% application_name %],DC=Test Deployment,DC=OpenXPKI,DC=org",
                },
                ui => {
                    info => [
                        "requestor_gname", "requestor_name",
                        "requestor_email", "requestor_affiliation",
                        "comment",
                    ],
                    subject => [ "hostname", "application_name" ],
                },
            },
        },
        validity => { notafter => "+01" },
        extensions => {
            extended_key_usage => {
                client_auth      => 1,
                code_signing     => 0,
                critical         => 1,
                email_protection => 0,
                server_auth      => 0,
                time_stamping    => 0,
                ocsp_signing     => 0,
            },
            key_usage => {
                critical          => 1,
                crl_sign          => 0,
                data_encipherment => 0,
                decipher_only     => 0,
                digital_signature => 1,
                encipher_only     => 0,
                key_agreement     => 0,
                key_cert_sign     => 0,
                key_encipherment  => 0,
                non_repudiation   => 0,
            },
        },
    };
}

sub _cert_profile_server {
    return {
        label => "I18N_OPENXPKI_UI_PROFILE_TLS_SERVER_LABEL",
        style => {
            "00_basic_style" => {
                description => "I18N_OPENXPKI_UI_PROFILE_BASIC_STYLE_DESC",
                label       => "I18N_OPENXPKI_UI_PROFILE_BASIC_STYLE_LABEL",
                metadata    => {
                    email     => "[% requestor_email %]",
                    entity    => "[% hostname FILTER lower %]",
                    requestor => "[% requestor_gname %] [% requestor_name %]",
                },
                subject => {
                    dn =>
                        "CN=[% hostname.lower %][% IF port AND port != 443 %]:[% port %][% END %],DC=Test Deployment,DC=OpenXPKI,DC=org",
                    san => {
                        DNS => [
                            "[% hostname.lower %]",
                            "[% FOREACH entry = hostname2 %][% entry.lower %] | [% END %]",
                        ],
                    },
                },
                ui => {
                    info => [
                        "requestor_gname", "requestor_name",
                        "requestor_email", "requestor_affiliation",
                        "comment",
                    ],
                    san     => [ "san_dns",  "san_ipv4" ],
                    subject => [ "hostname", "hostname2", "port" ],
                },
            },
            "05_advanced_style" => {
                description => "I18N_OPENXPKI_UI_PROFILE_ADVANCED_STYLE_DESC",
                label   => "I18N_OPENXPKI_UI_PROFILE_ADVANCED_STYLE_LABEL",
                subject => {
                    dn =>
                        "CN=[% CN %][% IF OU %][% FOREACH entry = OU %],OU=[% entry %][% END %][% END %][% IF O %],O=[% O %][% END %][% FOREACH entry = DC %],DC=[% entry %][% END %][% IF C %],C=[% C %][% END %]",
                },
                ui => {
                    info => [
                        "requestor_gname", "requestor_name",
                        "requestor_email", "requestor_affiliation",
                        "comment",
                    ],
                    subject => [ "cn", "o", "ou", "dc", "c" ],
                },
            },
            "enroll" => {
                metadata => {
                    entity    => "[% CN.0 FILTER lower %]",
                    server_id => "[% data.server_id %]",
                    system_id => "[% data.cust_id %]",
                },
                subject => {
                    dn =>
                        "CN=[% CN.0 %],DC=Test Deployment,DC=OpenXPKI,DC=org"
                },
            },
        },
        validity => { notafter => "+0006" },
        extensions => {
            extended_key_usage => {
                client_auth      => 0,
                code_signing     => 0,
                critical         => 1,
                email_protection => 0,
                server_auth      => 1,
                time_stamping    => 0,
            },
            key_usage => {
                critical          => 1,
                crl_sign          => 0,
                data_encipherment => 0,
                decipher_only     => 0,
                digital_signature => 1,
                encipher_only     => 0,
                key_agreement     => 0,
                key_cert_sign     => 0,
                key_encipherment  => 1,
                non_repudiation   => 0,
            },
            netscape => {
                cdp => {
                    ca_uri   => "http://localhost/cacrl.crt",
                    critical => 0,
                    uri      => "http://localhost/cacrl.crt",
                },
                certificate_type => {
                    critical          => 0,
                    object_signing    => 0,
                    object_signing_ca => 0,
                    smime_client      => 0,
                    smime_client_ca   => 0,
                    ssl_client        => 0,
                    ssl_client_ca     => 0,
                },
                comment => {
                    critical => 0,
                    text =>
                        "This is a generic certificate. Generated with OpenXPKI trustcenter software.",
                },
            },
        },
    };
}

sub _cert_profile_user {
    return {
        label => "I18N_OPENXPKI_UI_PROFILE_USER_LABEL",
        style => {
            "00_user_basic_style" => {
                description => "I18N_OPENXPKI_UI_PROFILE_BASIC_STYLE_DESC",
                label       => "I18N_OPENXPKI_UI_PROFILE_BASIC_STYLE_LABEL",
                metadata    => {
                    department => "[% department %]",
                    email      => "[% email %]",
                    requestor  => "[% realname %]",
                },
                subject => {
                    dn =>
                        "CN=[% realname %]+UID=[% username %][% IF department %],DC=[% department %][% END %],DC=Test Deployment,DC=OpenXPKI,DC=org",
                    san => { email => "[% email.lower %]" },
                },
                ui => {
                    info => ["comment"],
                    subject =>
                        [ "username", "realname", "department", "email" ],
                },
            },
        },
        validity => { notafter => "+0006" },
        extensions => {
            extended_key_usage => {
                "1.3.6.1.4.1.311.20.2.2" => 1,
                "client_auth"            => 1,
                "code_signing"           => 0,
                "critical"               => 1,
                "email_protection"       => 1,
                "server_auth"            => 0,
                "time_stamping"          => 0,
            },
            key_usage => {
                critical          => 1,
                crl_sign          => 0,
                data_encipherment => 0,
                decipher_only     => 0,
                digital_signature => 1,
                encipher_only     => 0,
                key_agreement     => 0,
                key_cert_sign     => 0,
                key_encipherment  => 1,
                non_repudiation   => 1,
            },
        },
    };
}

sub _crl_default {
    return {
        digest     => "sha256",
        extensions => {
            authority_info_access => { critical => 0 },
            authority_key_identifier =>
                { critical => 0, issuer => 1, keyid => 1 },
            issuer_alt_name => { copy => 0, critical => 0 },
        },
        validity => {
            lastcrl    => 20301231235900,
            nextupdate => "+000014",
            renewal    => "+000003",
        },
    };
}


sub _system_realm {
    my ($self, $realm) = @_;
    return {
        label => uc($realm)." test realm",
        baseurl => sprintf("http://127.0.0.1:8080/openxpki/$realm/"),
        description => "Description for $realm",
    };
}

1;
