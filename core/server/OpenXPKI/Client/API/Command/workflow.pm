package OpenXPKI::Client::API::Command::workflow;
use OpenXPKI -role;

use OpenXPKI::Serialization::Simple;

=head1 NAME

OpenXPKI::CLI::Command::workflow

=head1 DESCRIPTION

Show and interact with workflows.

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
