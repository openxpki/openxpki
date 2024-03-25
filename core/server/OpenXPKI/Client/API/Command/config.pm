package OpenXPKI::Client::API::Command::config;

use Moose;
extends 'OpenXPKI::Client::API::Command';

# Core modules
use Data::Dumper;
use List::Util qw( none );


=head1 NAME

OpenXPKI::CLI::Command::config

=head1 SYNOPSIS

Show and handle OpenXPKI system configuarion

=head1 USAGE

Feed me!

=head2 Subcommands

=over

=item show

=item verify

=item smtptest

=back

=cut

__PACKAGE__->meta()->make_immutable();

1;
