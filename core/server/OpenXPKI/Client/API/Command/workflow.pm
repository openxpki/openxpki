package OpenXPKI::Client::API::Command::workflow;
use OpenXPKI -role;

with 'OpenXPKI::Client::API::Command';

# Core modules
use List::Util qw( none );

use OpenXPKI::Serialization::Simple;

=head1 NAME

OpenXPKI::CLI::Command::workflow

=head1 SYNOPSIS

Show and interact with workflows in OpenXPKI

=head1 USAGE

Feed me!

=head2 Subcommands

=over

=item list

=item show

=item create

=item execute

=item wakeup

=item resume

=item reset

=item fail

=item archive

=back

=cut

sub deserialize_context {
    my $self = shift;
    my $response = shift;

    return unless($response->isa('OpenXPKI::DTO::Message::Response'));

    my $ctx = $response->params()->{workflow}->{context};
    my $ser = OpenXPKI::Serialization::Simple->new();
    foreach my $key (keys (%{$ctx})) {
        next unless (OpenXPKI::Serialization::Simple::is_serialized($ctx->{$key}));
        $ctx->{$key} = $ser->deserialize($ctx->{$key});
    }
}

1;
