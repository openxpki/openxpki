package OpenXPKI::Test::DBI;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::DBI - Test helper to get a database handle

=cut

# Project modules
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Context qw( CTX );


has dbi => (
    is => 'ro',
    isa => 'OpenXPKI::Server::Database',
    lazy => 1,
    default => sub {
        CTX('dbi') or die "Could not instantiate database backend\n";
    },
);

=head1 METHODS

=cut

sub BUILD {
    my $self = shift;
    $ENV{OPENXPKI_CONF_PATH} = '/etc/openxpki/config.d';
    OpenXPKI::Server::Init::init({
        TASKS  => ['config_versioned','log','dbi'],
        SILENT => 1,
        CLI => 1,
    });
}
 

__PACKAGE__->meta->make_immutable;
