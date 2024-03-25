package OpenXPKI::Client::API::Command::workflow;

use Moose;
extends 'OpenXPKI::Client::API::Command';
with 'OpenXPKI::Client::API::Command::NeedRealm';

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

=item wakeup

=item resume

=item reset

=item fail

=item archive

=back

=cut

__PACKAGE__->meta()->make_immutable();

1;
