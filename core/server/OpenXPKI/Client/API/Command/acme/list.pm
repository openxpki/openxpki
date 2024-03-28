package OpenXPKI::Client::API::Command::acme::list;

use Moose;
extends 'OpenXPKI::Client::API::Command::acme';

use MooseX::ClassAttribute;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::String;
use OpenXPKI::DTO::Field::Realm;

=head1 NAME

OpenXPKI::Client::API::Command::acme::list

=head1 SYNOPSIS

List all ACME account entries from the datapool

Shows the datapool id, the account kid and the key thumbprint.
To get account data and key information please use I<show>.

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;


    my $res = $self->api->run_command('list_data_pool_entries', {
        namespace => 'nice.acme.account',
    });

    my @result;
    foreach my $account (@{$res->result}) {
        $res = $self->api->run_command('get_data_pool_entry', {
            namespace => 'nice.acme.account',
            key => $account->{key},
            deserialize => 'simple',
        });
        push @result, {
            key_id => $account->{key},
            kid =>    $res->{value}->{kid},
            thumbprint => $res->{value}->{thumbprint},
        };
    }
    return OpenXPKI::Client::API::Response->new( payload =>\@result );
}

__PACKAGE__->meta()->make_immutable();

1;

