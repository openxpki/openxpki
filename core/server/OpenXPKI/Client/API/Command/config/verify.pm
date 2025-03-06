package OpenXPKI::Client::API::Command::config::verify;
use OpenXPKI -client_plugin;

# TODO - this is not protected but does not need a realm as its local...
command_setup
    parent_namespace_role => 1,
    protected => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::config::verify

=head1 DESCRIPTION

Verify the content of a directory holding a YAML system configuration.

Contrary to I<config show> this works on a local copy and does not query
the running instance!

=cut

# CPAN modules
use Mojo::Loader;

# Project modules
use OpenXPKI::Config::Backend;

command "verify" => {
    config => { isa => 'ReadableDir', label => 'Path to local config tree', default => '/etc/openxpki/config.d' },
    path => { isa => 'Str', label => 'Path to dump' },
    module => { isa => 'Str', label => 'Optional linter module' },
} => sub ($self, $param) {

    my $res;
    # the given path is known to exist as this is checked by the validator already!
    my $conf = OpenXPKI::Config::Backend->new( LOCATION => $param->config );
    # YAML was ok but there is no system node
    die 'No *system* node was found' unless $conf->get_hash('system');

    if ($param->has_path) {
        my @path = split /\./, $param->path;
        my $hash = $conf->get_hash( shift @path );
        foreach my $item (@path) {
            if (!defined $hash->{$item}) {
                die "No such component ($item)";
            }
            $hash = $hash->{$item};
        }
        $res = { digest => $conf->checksum, path => $param->path, value => $hash };

    } elsif ($param->has_module) {
        my $res_lint = $self->lint_module($conf, $param->module, $self->build_hash_from_payload($param));
        $res = { digest => $conf->checksum, $param->module => $res_lint };

    } else {

        $res = { digest => $conf->checksum };

    }

    return $res;

};

sub lint_module ($self, $config, $module, $params) {
    my $uc_module = ucfirst($module);
    my $class = "OpenXPKI::Config::Lint::$uc_module";
    if (Mojo::Loader::load_class($class)) {
        die "Unable to load linter module '$uc_module'";
    }
    $self->log->debug("Linting module '$uc_module'");
    my $linter = $class->new(
        config => $config,
        $params->{realm} ? (realm => $params->{realm}) : (),
        $uc_module eq 'Workflow' && $params->{workflow} ? (workflow => $params->{workflow}) : (),
    );
    return $linter->lint;
}

__PACKAGE__->meta->make_immutable;



