package OpenXPKI::Server::API2::Plugin::Cert::get_cert_attributes;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::get_cert_attributes

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

with 'OpenXPKI::Server::API2::TenantRole';

=head1 COMMANDS

=head2 get_cert_attributes

Get a list of (selected) certificate attributes.

Returns a I<HashRef> with the attribute names and the lists of values (muliple
attributes of the same name are allowed):

    {
        meta_email => [ 'nn@example.org', 'nicer@example.org' ],
        meta_requestor => [ 'Nice Nephew' ],
    }

B<Parameters>

=over

=item * C<identifier> I<Str> - internal OpenXPKI identifier of the certificate

=item * C<attribute> I<Str> - SQL search string to filter the list of returned
attributes. Will be applied with SQL LIKE operator, so "%" wildcards are allowed.
Optional.

=back

=cut
command "get_cert_attributes" => {
    identifier => { isa => 'Base64', required => 1, },
    attribute  => { isa => 'Str', },
} => sub {
    my ($self, $params) = @_;

    my $query = { identifier => $params->identifier };

    if ($params->has_attribute) {
        $query->{attribute_contentkey} = { -like => $params->attribute };
    }

    my $sth_attrib = CTX('dbi')->select(
        from => 'certificate_attributes',
        columns => [ 'attribute_contentkey', 'attribute_value' ],
        where => $query,
    );

    my $attrib;
    while (my $item = $sth_attrib->fetchrow_hashref) {
        my $key = $item->{attribute_contentkey};
        my $val = $item->{attribute_value};
        $attrib->{$key} //= [];
        push @{$attrib->{$key}}, $val;
    }

    return $attrib;
};

__PACKAGE__->meta->make_immutable;
