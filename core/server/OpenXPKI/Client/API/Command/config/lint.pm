package OpenXPKI::Client::API::Command::config::lint;

use Moose;
extends 'OpenXPKI::Client::API::Command::config';
# TODO - this is not protected but does not need a realm as its local...
with 'OpenXPKI::Client::API::Command::Protected';

use MooseX::ClassAttribute;

use Data::Dumper;
use Feature::Compat::Try;
use Log::Log4perl qw(:easy);


use OpenXPKI::Config::Backend;
use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::String;
use OpenXPKI::DTO::Field::Directory;
use OpenXPKI::DTO::Message::ErrorResponse;
use OpenXPKI::DTO::Message::Response;
use OpenXPKI::DTO::ValidationException;
use OpenXPKI::Serialization::Simple;

=head1 NAME

OpenXPKI::Client::API::Command::config::show;

=head1 SYNOPSIS

Show information of the (running) OpenXPKI configuration

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::Directory->new( name => 'config', label => 'Path to local config tree', value => '/etc/openxpki/config.d' ),
        OpenXPKI::DTO::Field::String->new( name => 'path', label => 'Path to dump' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;
    try {

        my $res;
        # the given path is known to exist as this is checked by the validator already!
        my $conf = OpenXPKI::Config::Backend->new( LOCATION => $req->param('config') );
        # YAML was ok but there is no system node
        if (!$conf->get_hash('system')) {
            die 'No *system* node was found';
        } elsif (my $path = $req->param('path')) {
            my @path = split /\./, $path;
            my $hash = $conf->get_hash( shift @path );
            foreach my $item (@path) {
                if (!defined $hash->{$item}) {
                    die "No such component ($item)";
                }
                $hash = $hash->{$item};
            }
            $res = OpenXPKI::DTO::Message::Response->new(
                params => {
                    digest => $conf->checksum(),
                    path => $path,
                    value => $hash
                }
            );
        } else {
            $res = OpenXPKI::DTO::Message::Response->new(
                params => { digest => $conf->checksum() }
            );
        }

        return OpenXPKI::Client::API::Response->new( payload => $res );
    } catch ($err) {
        return OpenXPKI::Client::API::Response->new( state => 400, payload => $err );
    }

}

__PACKAGE__->meta()->make_immutable();

1;


