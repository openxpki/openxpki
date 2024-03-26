package OpenXPKI::Client::API::Command::alias;

use Moose;
extends 'OpenXPKI::Client::API::Command';

# Core modules
use Data::Dumper;
use List::Util qw( none );


=head1 NAME

OpenXPKI::CLI::Command::token

=head1 SYNOPSIS

Show and handle OpenXPKI alias configuarion

=head1 USAGE

Feed me!

=head2 Subcommands

=over

=item show

=item add

=item create

=item list

=item remove

=back

=cut

__PACKAGE__->meta()->make_immutable();


sub preprocess {

    my $self = shift;
    my $req = shift;

    my $res = $self->_preprocess($req);

    return OpenXPKI::Client::API::Response->new(
        state => 400,
        payload => $res
    ) if ($res);

    # check if group / alias is not a token
    my ($group, $input);
    if ($req->param('group')) {
        $input = 'group';
        $group = $req->param('group');
    } elsif (my $alias = $req->param('alias')) {
        $input = 'alias';
        ($group) = $alias =~ m{(.*)-\d+\z};
    }
    return unless ($group);

    $self->log->debug('Alias from group ' . $group);
    my $groups = $self->api->run_command('list_token_groups');
    return if (none { $_ eq $group } values %{$groups->params});

    # TODO - throw exception
    return OpenXPKI::Client::API::Response->new(
        state => 400,
        payload => OpenXPKI::DTO::ValidationException->new(
            field => $input, reason => 'value',
            message => 'Given alias group must be handled using the token command'
        )
    );
}


1;
