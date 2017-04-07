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

# CPAN modules
use Moose::Util::TypeConstraints;
use Test::More;
use Test::Exception;
use Test::Deep::NoTest qw( eq_deeply bag ); # use eq_deeply() without beeing in a test

=head1 DESCRIPTION

Methods to create a configuration consisting of several YAML files for tests.

=cut

has basedir     => ( is => 'rw', isa => 'Str', required => 1 );

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

# Following attributes must be lazy => 1 because their builders access other attributes
has yaml_crypto     => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_crypto" );
has yaml_database   => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_database" );
has yaml_realms     => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_realms" );
has yaml_server     => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_server" );
has yaml_watchdog   => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_watchdog" );
has conf_log4perl   => ( is => 'rw', isa => 'Str',     lazy => 1, builder => "_buikd_log4perl" );

has realms          => ( is => 'rw', isa => 'ArrayRef', default => sub { [ 'alpha', 'beta', 'gamma' ] } );

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

has system_user  => ( is => 'rw', isa => 'Str', lazy => 1, default => "openxpki" );
has system_group => ( is => 'rw', isa => 'Str', lazy => 1, default => "openxpki" );


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
    print $fh $content, "\n";
    close $fh;
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
    $self->write_str($filepath, join("\n", @$lines));
}

sub write_realm_config {
    my ($self, $realm, $config_path, $yaml_hash) = @_;

    my $relpath = $config_path; $relpath =~ s/\./\//g;
    $self->write_yaml($self->path_config_dir."/realm/$realm/$relpath.yaml",  $yaml_hash)
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
    $self->write_yaml($self->path_config_dir."/system/crypto.yaml",    $self->yaml_crypto);
    $self->write_yaml($self->path_config_dir."/system/database.yaml",  $self->yaml_database);
    $self->write_yaml($self->path_config_dir."/system/realms.yaml",    $self->yaml_realms);
    $self->write_yaml($self->path_config_dir."/system/server.yaml",    $self->yaml_server);
    $self->write_yaml($self->path_config_dir."/system/watchdog.yaml",  $self->yaml_watchdog);

    $self->write_realm_config($_, "crypto", $self->_realm_crypto($_)) for @{$self->realms};

    $self->write_str ($self->path_log4perl_conf,                       $self->conf_log4perl);
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
            lifetime    => 1200,
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

sub _buikd_log4perl {
    my ($self, $realm) = @_;

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

__PACKAGE__->meta->make_immutable;
