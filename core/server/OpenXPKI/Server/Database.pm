package OpenXPKI::Server::Database;
use strict;
use warnings;
use feature 'state';

# Core modules
use Exporter qw( import );

=head1 NAME

OpenXPKI::Server::Database - Legacy compatibility with custom code

=head1 DESCRIPTION

This module exports the C<AUTO_ID> function to ensure the following expectation
in customer code is still satisfied:

    use OpenXPKI::Server::Database; # to get AUTO_ID

=cut

# Symbols to export by default
our @EXPORT = qw( AUTO_ID );

=head1 FUNCTIONS

=head2 AUTO_ID

Used in database C<INSERT>s to automatically set a primary key to the next
serial number (i.e. sequence associated with the table).

See L<OpenXPKI::Database/insert> for details.


=cut

sub AUTO_ID :prototype() {
    state $obj = bless {}, "OpenXPKI::Database::AUTOINCREMENT";
    return $obj;
}

1;
