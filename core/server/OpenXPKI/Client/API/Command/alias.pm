package OpenXPKI::Client::API::Command::alias;
use OpenXPKI -role;

# Core modules
use List::Util qw( any );

# Project modules
use OpenXPKI::DTO::ValidationException;

=head1 NAME

OpenXPKI::Client::API::Command::alias

=head1 DESCRIPTION

Show and handle alias configuration.

=cut

sub check_group ($self, $group) {
    $self->_assert_no_token_group('group', $group);
}

sub check_alias ($self, $alias) {
    my ($group) = $alias =~ m{(.*)-\d+\z};
    $self->_assert_no_token_group('alias', $group);
}

# check if group / alias is not a token
sub _assert_no_token_group ($self, $field_name, $group) {
    return unless $group;

    my $groups = $self->run_command('list_token_groups');
    return unless $groups;

    if (any { $_ eq $group } values %{$groups->params}) {
        die OpenXPKI::DTO::ValidationException->new(
            field => $field_name, reason => 'value',
            message => 'Given '.$field_name.' is a token group, it must be managed using the "token" command',
        );
    }
}

1;
