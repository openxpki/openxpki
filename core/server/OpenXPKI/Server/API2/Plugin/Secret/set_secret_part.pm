package OpenXPKI::Server::API2::Plugin::Secret::set_secret_part;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Secret::set_secret_part

=cut

# CPAN modules
use Feature::Compat::Try;

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 set_secret_part

Set the secret value of the given group, for secrets of type "literal" omit
C<part>.

B<Parameters>

=over

=item * C<secret> I<Str> - name of the secret (group). Required.

=item * C<part> I<Int> - part number (only for multipart secrets, i.e. type
"plain" or "split")

=item * C<value> I<Str> - value to set. Required.

=back

=cut
command "set_secret_part" => {
    secret => { isa => 'AlphaPunct', required => 1, },
    part   => { isa => 'Int', },
    value  => { isa => 'Str', required => 1, },
} => sub {
    my ($self, $params) = @_;

    try {
        CTX('crypto_layer')->set_secret_part({
            GROUP => $params->secret,
            $params->has_part ? (PART => $params->part) : (),
            VALUE => $params->value,
        });

        CTX('log')->audit('system')->info("set secret part", {
            group => $params->secret,
            $params->has_part ? (part => $params->part) : (),
        });
    }
    catch ($err) {
        CTX('log')->audit('system')->warn("incorrect secret given", {
            group => $params->secret,
            $params->has_part ? (part => $params->part) : (),
            error => "$err",
        });
        die $err;
    };

    return 1;
};

__PACKAGE__->meta->make_immutable;
