package OpenXPKI::Test::ConfigWriter;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::ConfigWriter - Create test configuration files (YAML)

=cut

# Core modules
use File::Path qw(make_path);
use File::Spec;
use TAP::Parser::YAMLish::Writer;
use POSIX;

# CPAN modules
use Moose::Util::TypeConstraints;
use Test::More;
use Test::Exception;
use Test::Deep::NoTest qw( eq_deeply bag ); # use eq_deeply() without beeing in a test

=head1 DESCRIPTION

Methods to create a configuration consisting of several YAML files for tests.

=cut

# TRUE if the initial configuration has been written
has is_written => (
    is => 'rw',
    isa => 'Bool',
    init_arg => undef,
    default => 0,
);

has basedir => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has db_conf => (
    is => 'rw',
    isa => 'HashRef',
    required => 1,
    trigger => sub {
        my ($self, $new, $old) = @_;
        my @keys = qw( type name host port user passwd );
        die "Required keys missing for 'db_conf': ".join(", ", grep { not defined $new->{$_} } @keys)
            unless eq_deeply([keys %$new], bag(@keys));
    },
);

# Collection of all config files (default and custom / user provided) that will
# be inserted into the test environment.
# They must be declared before we create() everything.
# HashRef: [dot-separated config path] => [YAML HashRef]
has _config_data => (
    is => 'ro',
    isa => 'HashRef[HashRef]',
    traits => ['Hash'],
    default => sub { {} },
    init_arg => undef, # disable assignment via construction
    handles => {
        get_config_rootentry => 'get',
        get_config_keys => 'keys',
    },
);

# Following attributes must be lazy => 1 because their builders access other attributes
has yaml_crypto     => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_crypto" );
has yaml_database   => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_database" );
has yaml_realms     => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_realms" );
has yaml_server     => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_server" );
has yaml_watchdog   => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_watchdog" );
has yaml_workflow_persister => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_workflow_persister" );
has conf_log4perl   => ( is => 'rw', isa => 'Str',     lazy => 1, builder => "_build_log4perl" );

has realms  => ( is => 'rw', isa => 'ArrayRef', default => sub { [ 'alpha', 'beta', 'gamma' ] } );
has yaml_cert_profile_template => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_cert_profile_template" );
has yaml_cert_profile_client   => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_cert_profile_client" );
has yaml_cert_profile_server   => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_cert_profile_server" );
has yaml_cert_profile_user     => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_cert_profile_user" );
has yaml_crl_default           => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_crl_default" );

has path_config_dir     => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->basedir."/etc/openxpki/config.d" } );
has path_session_dir    => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->basedir."/var/openxpki/session" } );
has path_temp_dir       => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->basedir."/var/tmp" } );
has path_export_dir     => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->basedir."/var/openxpki/dataexchange/export" } );
has path_import_dir     => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->basedir."/var/openxpki/dataexchange/import" } );
has path_socket_file    => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->basedir."/var/openxpki/openxpki.socket" } );
has path_pid_file       => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->basedir."/var/run/openxpkid.pid" } );
has path_stderr_file    => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->basedir."/var/log/openxpki/stderr.log" } );
has path_log_file       => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->basedir."/var/log/openxpki/catchall.log" } );
has path_log4perl_conf  => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->basedir."/etc/openxpki/log.conf" } );

has path_openssl        => ( is => 'rw', isa => 'Str', default => "/usr/bin/openssl" );
has path_javaks_keytool => ( is => 'rw', isa => 'Str', default => "/usr/bin/keytool" );
has path_openca_scep    => ( is => 'rw', isa => 'Str', default => "/usr/bin/openca-scep" );

has system_user  => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { (getpwuid(geteuid))[0] } ); # run under same user as test scripts
has system_group => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { (getgrgid(getegid))[0] } );


sub _make_dir {
    my ($self, $dir) = @_;
    return if -d $dir;
    make_path($dir) or die "Could not create temporary directory $dir: $@"
}

sub _make_parent_dir {
    my ($self, $filepath) = @_;
    # Strip off filename portion to create parent dir
    $self->_make_dir( File::Spec->catpath((File::Spec->splitpath( $filepath ))[0,1]) );
}

sub write_str {
    my ($self, $filepath, $content) = @_;

    die "Empty content for $filepath" unless $content;
    open my $fh, ">", $filepath or die "Could not open $filepath for writing: $@";
    print $fh $content, "\n" or die "Could not write to $filepath: $@";
    close $fh or die "Could not close $filepath: $@";
}

sub write_private_key {
    my ($self, $realm, $alias, $pem_str) = @_;

    my $filepath = $self->_private_key_path($realm, $alias);
    $self->_make_parent_dir($filepath);
    $self->write_str($filepath, $pem_str);
}

sub remove_private_key {
    my ($self, $realm, $alias) = @_;

    my $filepath = $self->_private_key_path($realm, $alias);
    unlink $filepath or die "Could not remove file $filepath: $@";
}

sub write_yaml {
    my ($self, $filepath, $data) = @_;

    my $lines = [];
    TAP::Parser::YAMLish::Writer->new->write($data, $lines);
    pop @$lines; shift @$lines; # remove --- and ... from beginning/end

    $self->_make_parent_dir($filepath);
    diag "Writing $filepath" if $ENV{TEST_VERBOSE};
    $self->write_str($filepath, join("\n", @$lines));
}

sub add_config {
    my ($self, $config_path, $yaml_hash) = @_;
    die "add_config() must be called before create()" if $self->is_written;
    $self->_config_data->{$config_path} = $yaml_hash;
}

# Returns a hash that contains all config data that was defined for the given
# config path.
# The data might be taken from parent and/or child keys, e.g.:
# get_config_entry('realm.alpha.workflow') might return data from
#  realm/alpha.yaml
#  realm/alpha/workflow.yaml
#  realm/alpha/workflow/def/creation.yaml
#  realm/alpha/workflow/def/deletion.yaml
sub get_config_node {
    my ($self, $config_key, $allow_undef) = @_;
    my $result = {};

    # Part 1: exact matches and superkeys
    my @parts = split /\./, $config_key;
    for my $i (0..$#parts) {
        my $curr_path = join ".", @parts[0..$i];
        if (my $config_hash = $self->_config_data->{$curr_path}) {
            # see if we the requested config path is part of the hash
            my $node = $config_hash;
            for (my $r=$i+1; $r <= $#parts; $r++) {
                $node = $node->{$parts[$r]} or last;
            }
            if ($node) {
                return $node unless ref $node; # special treatment for leafs
                %$result = (%$node, %$result);
            }
        }
    }

    # Part 2: subkeys
    my @subkeys = grep { $_ =~ / ^ \Q$config_key\E \. /msx } sort $self->get_config_keys;
    for my $subkey (@subkeys) {
        my $rel_key = $subkey; $rel_key =~ s/ ^ \Q$config_key\E \. //msx;
        my @rel_parts = split /\./, $rel_key;
        my $node = $result;
        for my $i (0..$#rel_parts-1) {
            $node->{$rel_parts[$i]} //= {};
            $node = $node->{$rel_parts[$i]};
        }
        $node->{$rel_parts[$#rel_parts]} = $self->get_config_rootentry($subkey);
    }

    if (not %$result) {
        die "Configuration key $config_key not found" unless $allow_undef;
        $result = undef;
    }
    return $result;
}

sub add_realm_config {
    my ($self, $realm, $config_path, $yaml_hash) = @_;
    die "add_realm_config() must be called before create()" if $self->is_written;
    $self->add_config("realm.$realm.$config_path" => $yaml_hash);
}

sub make_dirs {
    my ($self) = @_;
    # Do explicitely not create $self->basedir to prevent accidential use of / etc
    diag "Creating directory ".$self->path_config_dir if $ENV{TEST_VERBOSE};
    $self->_make_dir($self->path_config_dir);
    $self->_make_dir($self->path_session_dir);
    $self->_make_dir($self->path_temp_dir);
    $self->_make_dir($self->path_export_dir);
    $self->_make_dir($self->path_import_dir);
    $self->_make_parent_dir($self->path_socket_file);
    $self->_make_parent_dir($self->path_pid_file);
    $self->_make_parent_dir($self->path_stderr_file);
    $self->_make_parent_dir($self->path_log4perl_conf);
}

sub create {
    my ($self) = @_;
    $self->make_dirs;
    $self->add_config("system.crypto"   => $self->yaml_crypto);
    $self->add_config("system.database" => $self->yaml_database);
    $self->add_config("system.realms"   => $self->yaml_realms);
    $self->add_config("system.server"   => $self->yaml_server);
    $self->add_config("system.watchdog" => $self->yaml_watchdog);

    for my $realm (@{$self->realms}) {
        $self->add_realm_config($realm, "crypto", $self->_realm_crypto($realm));
        $self->add_realm_config($realm, "workflow.persister", $self->yaml_workflow_persister);
        # OpenXPKI::Workflow::Handler checks existance of workflow.def
        $self->add_realm_config($realm, "workflow.def.empty", { state => { INITIAL => { } } });
        # certificate profiles
        $self->add_realm_config($realm, "profile.template",                     $self->yaml_cert_profile_template);
        $self->add_realm_config($realm, "profile.I18N_OPENXPKI_PROFILE_CLIENT", $self->yaml_cert_profile_client);
        $self->add_realm_config($realm, "profile.I18N_OPENXPKI_PROFILE_SERVER", $self->yaml_cert_profile_server);
        $self->add_realm_config($realm, "profile.I18N_OPENXPKI_PROFILE_USER",   $self->yaml_cert_profile_user);
        # CRL
        $self->add_realm_config($realm, "crl.default",                          $self->yaml_crl_default);
    }

    # write all config files
    for my $key (sort $self->get_config_keys) { # $key is the dot separated config path (e.g. system.database)
        my $relpath = $key; $relpath =~ s/\./\//g;
        my $filepath = sprintf "%s/%s.yaml", $self->path_config_dir, $relpath;
        $self->write_yaml($filepath, $self->get_config_rootentry($key));
    }
    # write Log4perl config
    $self->write_str($self->path_log4perl_conf, $self->conf_log4perl);

    $self->is_written(1);
}

# Returns the private key path for the certificate specified by realm and alias.
sub _private_key_path {
    my ($self, $realm, $alias) = @_;
    return sprintf "%s/etc/openxpki/ssl/%s/%s.pem", $self->basedir, $realm, $alias;
}

sub _build_database {
    my ($self) = @_;
    return {
        main => {
            debug   => 0,
            type    => $self->db_conf->{type},
            name    => $self->db_conf->{name},
            host    => $self->db_conf->{host},
            port    => $self->db_conf->{port},
            user    => $self->db_conf->{user},
            passwd  => $self->db_conf->{passwd},
        },
    };
}

sub _build_crypto {
    my ($self) = @_;
    return {
        # API classs to be used for different types of *realm* tokens
        # Undefined values default to OpenXPKI::Crypto::Backend::API
        tokenapi => {
            certsign  => "OpenXPKI::Crypto::Backend::API",
            crlsign   => "OpenXPKI::Crypto::Backend::API",
            datasafe  => "OpenXPKI::Crypto::Backend::API",
            scep      => "OpenXPKI::Crypto::Tool::SCEP::API",
        },
        # System wide token (non key based tokens)
        token => {
            default => {
                backend     => "OpenXPKI::Crypto::Backend::OpenSSL",
                api         => "OpenXPKI::Crypto::Backend::API",
                engine      => "OpenSSL",
                key_store   => "OPENXPKI",

                # OpenSSL binary location
                shell       => $self->path_openssl,

                # OpenSSL binary call gets wrapped with this command
                wrapper     => "",

                # random file to use for OpenSSL
                randfile    => $self->basedir."/var/openxpki/rand",
            },
            javaks => {
                backend     => "OpenXPKI::Crypto::Tool::CreateJavaKeystore",
                api         => "OpenXPKI::Crypto::Tool::CreateJavaKeystore::API",
                engine      => "OpenSSL",
                key_store   => "OPENXPKI",
                shell       => $self->path_javaks_keytool,
                randfile    => $self->basedir."/var/openxpki/rand",
            },
        }
    };
}

sub _build_realms {
    my ($self) = @_;

    my $i = 0;

    return {
        map {
            $i++;
            $_ => {
                label => uc($_)." test realm",
                baseurl => "http://127.0.0.1:808$i/openxpki/",
                description => "This is the realm description #$i",
            }
        }
        @{$self->realms}
    };
}

sub _build_server {
    my ($self) = @_;
    return {
        # Shown in the processlist to distinguish multiple instances
        name => "oxi-test",
        # this is the former server_id/server_shift from the database config
        shift => 8,
        node => {
            id =>  0,
        },
        # Location of the log4perl configuration
        log4perl => $self->path_log4perl_conf,
        # Daemon settings
        user        => $self->system_user,
        group       => $self->system_group,
        socket_file => $self->path_socket_file,
        pid_file    => $self->path_pid_file,
        stderr      => $self->path_stderr_file,
        tmpdir      => $self->path_temp_dir,
        #environment => {
        #    key => value,
        #}
        # Session
        session => {
            directory   => $self->path_session_dir,
            lifetime    => 600,
        },
        # Which transport to initialize
        transport => {
            Simple => 1,
        },
        # Which services to initialize
        service => {
            Default => {
                enabled => 1,
                timeout => 120,
            },
            SCEP => {
                enabled => 1,
            },
        },
        # settings for i18n
        i18n => {
            locale_directory => "/usr/share/locale",
            default_language => "C",
        },
        # Dataexhange directories - might be wise to have this per realm?
        data_exchange => {
            export => $self->path_export_dir,
            import => $self->path_import_dir,
        },
    };
}

sub _build_watchdog {
    my ($self) = @_;
    return {
        max_fork_redo => 5,
        max_exception_threshhold => 10,
        interval_sleep_exception => 60,
        max_tries_hanging_workflows =>  3,

        interval_wait_initial => 30,
        interval_loop_idle => 5,
        interval_loop_run => 1,

        # You should not change this unless you know what you are doing
        max_instance_count => 1,
        disabled => 0,
    };
}

sub _realm_crypto {
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
                key => $self->_private_key_path($realm, "[% ALIAS %]"),

                # possible values are OpenSSL, nCipher, LunaCA
                engine => "OpenSSL",
                engine_section => '',
                engine_usage => '',
                key_store => "OPENXPKI",

                # OpenSSL binary location
                shell => $self->path_openssl,

                # OpenSSL binary call gets wrapped with this command
                wrapper => '',

                # random file to use for OpenSSL
                randfile => $self->basedir."/var/openxpki/rand",

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
                shell => $self->path_openca_scep,
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

sub _build_workflow_persister {
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

sub _build_log4perl {
    my ($self) = @_;

    my $threshold_screen = $ENV{TEST_VERBOSE} ? 'INFO' : 'OFF';
    my $logfile = $self->path_log_file;

    return qq(
        log4perl.category.openxpki.auth         = INFO, Screen, Logfile, DBI
        log4perl.category.openxpki.audit        = INFO, Screen, DBI
        log4perl.category.openxpki.monitor      = INFO, Screen, Logfile
        log4perl.category.openxpki.system       = INFO, Screen, Logfile
        log4perl.category.openxpki.workflow     = INFO, Screen, Logfile
        log4perl.category.openxpki.application  = INFO, Screen, Logfile, DBI
        log4perl.category.connector             = INFO, Screen, Logfile

        log4perl.appender.Screen                = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.layout         = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Screen.layout.ConversionPattern = %d %c.%p %m%n
        log4perl.appender.Screen.Threshold      = $threshold_screen

        log4perl.appender.Logfile               = Log::Log4perl::Appender::File
        log4perl.appender.Logfile.filename      = $logfile
        log4perl.appender.Logfile.layout        = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Logfile.layout.ConversionPattern = %d %c.%p:%P %m%n
        log4perl.appender.Logfile.syswrite      = 1
        log4perl.appender.Logfile.utf8          = 1

        log4perl.appender.DBI                   = OpenXPKI::Server::Log::Appender::DBI
        log4perl.appender.DBI.layout            = Log::Log4perl::Layout::NoopLayout
        log4perl.appender.DBI.warp_message      = 0
    );
}

sub _build_crl_default {
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

sub _build_cert_profile_client {
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

sub _build_cert_profile_server {
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

sub _build_cert_profile_user {
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

sub _build_cert_profile_template {
    return {
        publish                 => [ "queue", "disk" ],
        randomized_serial_bytes => 8,
        increasing_serials => 1,
        digest     => "sha256",
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
        validity => { notafter => "+01" },
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
    };
}

sub cert_profile_template {
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

__PACKAGE__->meta->make_immutable;
