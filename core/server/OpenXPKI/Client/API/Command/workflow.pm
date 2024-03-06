package OpenXPKI::Client::API::Command::workflow;

use Moose;
extends 'OpenXPKI::Client::API::Command';

# Core modules
use Data::Dumper;
use List::Util qw( none );


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

=back

=cut

sub _build_parameters_from_request {

    my $self = shift;
    my $req = shift;
    return {} unless ($req->payload());

    my %wf_parameters;
    foreach my $arg (@{$req->payload()}) {
        my ($key, $val) = split('=', $arg, 2);
        if ($wf_parameters{$key}) {
            if (!ref $wf_parameters{$key}) {
                $wf_parameters{$key} = [$wf_parameters{$key}, $val];
            } else {
                push @{$wf_parameters{$key}}, $val;
            }
        } else {
            $wf_parameters{$key} = $val;
        }
    }
    return \%wf_parameters;

}

__PACKAGE__->meta()->make_immutable();

1;
