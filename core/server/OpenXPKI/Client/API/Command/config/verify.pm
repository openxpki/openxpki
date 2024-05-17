package OpenXPKI::Client::API::Command::config::verify;
use OpenXPKI -plugin;

with 'OpenXPKI::Client::API::Command::config';
set_namespace_to_parent;

# TODO - this is not protected but does not need a realm as its local...
with 'OpenXPKI::Client::API::Command::Protected';

use OpenXPKI::Config::Backend;

=head1 NAME

OpenXPKI::Client::API::Command::config::show;

=head1 SYNOPSIS

Show information of the (running) OpenXPKI configuration or
validate a configuration tree.

=cut

command "verify" => {
    config => { isa => 'ReadableDir', label => 'Path to local config tree', default => '/etc/openxpki/config.d' },
    path => { isa => 'Str', label => 'Path to dump' },
    module => { isa => 'Str', label => 'Optional linter module' },
} => sub ($self, $param) {

    my $res;
    # the given path is known to exist as this is checked by the validator already!
    my $conf = OpenXPKI::Config::Backend->new( LOCATION => $param->config );
    # YAML was ok but there is no system node
    if (!$conf->get_hash('system')) {
        die 'No *system* node was found';
    } elsif (my $path = $param->path) {
        my @path = split /\./, $path;
        my $hash = $conf->get_hash( shift @path );
        foreach my $item (@path) {
            if (!defined $hash->{$item}) {
                die "No such component ($item)";
            }
            $hash = $hash->{$item};
        }
        $res = {
            digest => $conf->checksum(),
            path => $path,
            value => $hash
        };
    } elsif (my $module = $param->module) {
        my $res_lint = $self->lint_module($conf, $module, $self->_build_hash_from_payload($param));

        $res = { digest => $conf->checksum(), $module => $res_lint };

    } else {
        $res = { digest => $conf->checksum() };
    }

    return $res;

};

sub lint_module {
    my $self = shift;
    my $config = shift;
    my $module = shift;
    my $params = shift;

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



