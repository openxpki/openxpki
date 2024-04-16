package OpenXPKI::Client::API::Command::datapool::show;

use Moose;
extends 'OpenXPKI::Client::API::Command::datapool';

use MooseX::ClassAttribute;

use Data::Dumper;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::Bool;
use OpenXPKI::DTO::Field::String;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::datapool

=head1 SYNOPSIS

Show a datapool entry, without any extra options prints the raw content
as blob, add the I<deserialize> and I<decrpty> flag to get the actual
payload, add I<metadata> to obtain the full entry with all structural
information.

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'namespace', label => 'Namespace', hint => 'hint_namespace', required => 1 ),
        OpenXPKI::DTO::Field::String->new( name => 'key', label => 'Key if the item to be removed', hint => 'hint_key',required => 1 ),
        OpenXPKI::DTO::Field::Bool->new( name => 'metadata', label => 'Show Metadata' ),
        OpenXPKI::DTO::Field::Bool->new( name => 'decrypt', label => 'Decrypt encrypted items' ),
        OpenXPKI::DTO::Field::Bool->new( name => 'deserialize', label => 'Deserialize Item', description => 'Unpack serialized value' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my %param;
    if ($req->param('decrypt')) {
        $param{'with_attributes'} = 1;
    }

    my $res = $self->api->run_command('get_data_pool_entry', {
        namespace => $req->param('namespace'),
        key =>  $req->param('key'),
        decrypt => ($req->param('decrypt') ? 1 :0),
        ($req->param('deserialize') ? (deserialize => 'simple') : ()),

    });

    if (!$req->param('metadata')) {
        $res = { result => $res->param('value') };
    }

    return OpenXPKI::Client::API::Response->new( payload => $res );

}

__PACKAGE__->meta()->make_immutable();

1;


