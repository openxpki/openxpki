package OpenXPKI::Client::API::Command::acme::list;

use Moose;
extends 'OpenXPKI::Client::API::Command::acme';

use MooseX::ClassAttribute;

use JSON::PP qw(decode_json);
use Data::Dumper;
use Feature::Compat::Try;

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
        OpenXPKI::DTO::Field::Realm->new( required => 1 ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my $client;
    try {
        $client = $self->client($req->param('realm'));

        my $res = $client->run_command('list_data_pool_entries', {
            namespace => 'nice.acme.account',
        });

        my @result;
        foreach my $account (@$res) {
            $res = $client->run_command('get_data_pool_entry', {
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
        return OpenXPKI::Client::API::Response->new( payload => \@result );
    } catch ($err) {
        return OpenXPKI::Client::API::Response->new( state => 400, payload => $err );
    }

}

__PACKAGE__->meta()->make_immutable();

1;

