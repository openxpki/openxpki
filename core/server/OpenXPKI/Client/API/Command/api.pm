package OpenXPKI::Client::API::Command::api;

use Moose;
extends 'OpenXPKI::Client::API::Command';

# Core modules
use Data::Dumper;
use List::Util qw( none );


=head1 NAME

OpenXPKI::CLI::Command::api

=head1 SYNOPSIS

Run commands of the OpenXPKI API

=head1 USAGE

Feed me!

=cut


sub list_command {

    my $self = shift;
    my $req = shift;

    my $actions = $self->api->run_enquiry('command');
    $self->log->trace(Dumper $actions->result) if ($self->log->is_trace);
    return $actions->result || [];

}

sub help_command {

    my $self = shift;
    my $command = shift;
    return $self->api->run_enquiry('command', { command => $command })->params;

}

sub execute_command {

    my $self = shift;
    my $command = shift;
    my $params = shift;
    return $self->api->run_command($command, $params);

}


__PACKAGE__->meta()->make_immutable();

1;
