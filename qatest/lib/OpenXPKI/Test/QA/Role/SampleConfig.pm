package OpenXPKI::Test::QA::Role::SampleConfig;
use Moose::Role;

=head1 NAME

OpenXPKI::Test::QA::Role::SampleConfig - Moose role that extends L<OpenXPKI::Test>
to include the complete sample configuration from `config/openxpki/config.d`

=cut

# Core modules
use POSIX;

# CPAN modules
use Test::More;
use File::Find;
use File::Spec;
use File::Basename qw( fileparse );
use Cwd qw( abs_path );
use FindBin qw( $Bin );

# Project modules
use YAML::Tiny;


requires "testenv_root";

=head1 DESCRIPTION

Applying this role performs the following actions:

=over

=item * create various new directories below L<testenv_root|OpenXPKI::Test/testenv_root>.

=item * load the OpenXPKI default configuration (shipped with the project),
modify it to work with tests and inject it into the test configuration.

Modifications made:

=over

=item * C<realm.ca-one.auth>: replace stacks, handler and roles with L<OpenXPKI::Test/auth_config>

=item * C<system.server>: replace process user/group and file locations

=item * C<system.watchdog>: set all intervals to 1 second and only activate
watchdog if constructor parameter C<start_watchdog =E<gt> 1> was passed to
C<OpenXPKI::Test>.

=back

=item * set C<CTX('session')->data->pki_realm> to I<ca-one>

=back

=head1 CONSTRUCTOR ENHANCEMENTS

This role add the following parameters to L<OpenXPKI::Test>s constructor:

=over

=item * I<start_watchdog> (optional) - Set to 1 to start the watchdog when the
test server starts up and allow later starts via API. Default: 0

=back

=cut
has start_watchdog => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    default => 0,
);

=back

=cut

has src_config_dir   => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { my(undef, $mydir, undef) = fileparse(__FILE__); abs_path($mydir."../../../../../../config/openxpki/config.d"); } );
has path_temp_dir    => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->testenv_root."/var/tmp" } );
has path_export_dir  => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->testenv_root."/var/openxpki/dataexchange/export" } );
has path_import_dir  => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->testenv_root."/var/openxpki/dataexchange/import" } );
has path_socket_file => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->testenv_root."/var/openxpki/openxpki.socket" } );
has path_pid_file    => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->testenv_root."/var/run/openxpkid.pid" } );
has path_stderr_file => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->testenv_root."/var/log/openxpki/stderr.log" } );

# BEFORE ... so OpenXPKI::Test->init_base_config wins with it's few base settings
before 'init_base_config' => sub { # happens before init_user_config() so we do not overwrite more specific configs of other roles
    my $self = shift;

    my(undef, $mydir, undef) = fileparse(__FILE__);
    my $config_dir = abs_path($mydir."/../../../../../../config/openxpki/config.d");
    die "Could not find OpenXPKI sample config dir" unless -d $config_dir;

    my $config = $self->config_writer;

    # Do explicitely not create $self->basedir to prevent accidential use of / etc
    $config->_make_dir($self->path_temp_dir);
    $config->_make_dir($self->path_export_dir);
    $config->_make_dir($self->path_import_dir);
    $config->_make_parent_dir($self->path_socket_file);
    $config->_make_parent_dir($self->path_pid_file);
    $config->_make_parent_dir($self->path_stderr_file);

    # add default configs
    $self->_load_default_config("realm/ca-one",         $self->can('_customize_ca_one'));          # can() returns a CodeRef
    $self->_load_default_config("system/crypto.yaml");
    # NO $self->_load_default_config("system.database") -- it's completely customized for tests
    $self->_load_default_config("system/realms.yaml");
    $self->_load_default_config("system/server.yaml",   $self->can('_customize_system_server'));   # can() returns a CodeRef
    $self->_load_default_config("system/watchdog.yaml", $self->can('_customize_system_watchdog')); # can() returns a CodeRef
};

after 'init_session_and_context' => sub {
    my $self = shift;
    # set PKI realm after init() as various init procedures overwrite the realm
    $self->session->data->pki_realm("ca-one") if $self->has_session;
};

# Loads the given default config YAML and adds it to the test environment,
# customizing it if an additional CodeRef is given.
sub _load_default_config {
    my ($self, $node, $customizer_coderef) = @_;
    my @parts = split /\//, $node;
    $parts[-1] =~ s/\.yaml$//; # strip ".yaml" if it's a file

    # read original sample confog
    my $config_hash = $self->_yaml2perl($self->src_config_dir, $node);
    # descent into config hash down to $node
    for (@parts) { $config_hash = $config_hash->{$_} };
    # customize config (call supplied method)
    $customizer_coderef->($self, $config_hash) if $customizer_coderef;
    # add configuration
    $self->add_config(join(".",@parts) => $config_hash);
    return $config_hash;
}

sub _customize_ca_one {
    my ($self, $conf) = @_;
    $conf->{auth} = $self->auth_config;
}

sub _customize_system_server {
    my ($self, $conf) = @_;

    # $conf->{log4perl} is set by OpenXPKI::Test->init_base_config later on
    # $conf->{session}  is set by OpenXPKI::Test->init_base_config later on

    # Daemon settings
    $conf->{user} =  (getpwuid(geteuid))[0]; # run under same user as test scripts
    $conf->{group} = (getgrgid(getegid))[0];
    $conf->{socket_file} = $self->path_socket_file;
    $conf->{pid_file} = $self->path_pid_file;
    $conf->{stderr} = $self->path_stderr_file;
    $conf->{tmpdir} = $self->path_temp_dir;

    $conf->{data_exchange} = {
        export => $self->path_export_dir,
        import => $self->path_import_dir,
    };
}

sub _customize_system_watchdog {
    my ($self, $conf) = @_;

    $conf->{interval_sleep_exception} = 1;
    $conf->{interval_wait_initial} = 1;
    $conf->{interval_loop_idle} = 1;
    $conf->{interval_loop_run} = 1;
    $conf->{disabled} = $self->start_watchdog ? 0 : 1;
}

# Reads the given single YAML file or directory with YAML files an parses
# them into a single huge configuration hash.
# Besides the config nodes in the YAML each subdirectory and file name also
# form one node in the hierarchy.
sub _yaml2perl {
    my ($self, $basedir, $path) = @_;
    $path =~ s/\/*$//; # strip trailing slash
    my $fullpath = $basedir."/".$path;
    my $filemap = {};

    my @basedir_parts = File::Spec->splitdir($basedir);

    my $processor = sub {
        my ($filepath) = @_;
        return unless $filepath =~ / \.yaml $/msxi;

        my ($vol, $tmp, $filename) = File::Spec->splitpath($filepath);
        my $dir = File::Spec->catpath($vol, $tmp);
        $dir =~ s/\/*$//; # strip trailing slash

        # slurp
        my $yaml = YAML::Tiny->read($filepath);

        # assemble relative path
        my @relpath = File::Spec->splitdir($dir);
        for (my $i=0; $i < scalar(@basedir_parts) and @relpath and $relpath[0] eq $basedir_parts[$i]; $i++) {
            shift @relpath; # remove parts of current path that equal base path
        }

        # strip extension from filename
        (my $leaf = $filename) =~ s/ \. [^\.]+ $//msxi;

        # merge definitions into config tree (root node is last dir of @base)
        my $node = $filemap;
        # create HashRef structure out of file paths
        for (@relpath) {
            $node->{$_} //= {}; # open new "node" if not existing
            $node = $node->{$_};
        }
        $node->{$leaf} = $yaml->[0];
    };

    if (-f $fullpath) {
        $processor->($fullpath);
    }
    else {
        find(
            {
                wanted => sub { $processor->($File::Find::name) },
                no_chdir => 1,
            },
            $fullpath
        );
    }

    return $filemap;
}

1;
