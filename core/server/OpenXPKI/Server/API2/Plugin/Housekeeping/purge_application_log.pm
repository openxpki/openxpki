package OpenXPKI::Server::API2::Plugin::Housekeeping::purge_application_log;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Housekeeping::purge_application_log

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 purge_application_log

Purge old records from the I<application_log> table.

B<Parameters>

=over

=item * C<maxage> I<Int> - maximum age (in seconds) of the application log
entries to preserve. Default: 180 days

=back

B<Changes compared to API v1:>

The previous parameter C<LEGACY> (to support old timestamp format) was removed.

=cut
command "purge_application_log" => {
    maxage => { isa => 'Int', default => 60*60*24*180 }, # 180 days
} => sub {
    my ($self, $params) = @_;
    return CTX('dbi')->delete(
        from => 'application_log',
        where => { logtimestamp => { "<", time - $params->maxage } },
    );
};

__PACKAGE__->meta->make_immutable;
