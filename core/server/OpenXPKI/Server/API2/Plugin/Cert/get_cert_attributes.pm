package OpenXPKI::Server::API2::Plugin::Cert::get_cert_attributes;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::get_cert_attributes

=cut

# Project modules
use OpenXPKI::Debug;
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

=item * C<identifier> I<Str> - OpenXPKI identifier

=item * C<attribute> I<ArrayRefOrStr>

SQL search string(s) to filter the list of returned attributes. Will
be applied with SQL LIKE operator, so "%" wildcards are allowed.
Optional.

=item * C<tenant> L<Tenant|OpenXPKI::Server::API2::Types/Tenant> - tenant

=back

=cut
command "get_cert_attributes" => {
    identifier => { isa => 'Base64', required => 1, },
    attribute  => { isa => 'ArrayRefOrStr', coerce => 1 },
    tenant  => { isa => 'Tenant', },
} => sub {
    my ($self, $params) = @_;

    ##! 16: $params->attribute
    my $query = { identifier => $params->identifier };

    if ($params->has_attribute) {
        my @conditions = map { { -like => $_ } } @{$params->attribute};
        $query->{attribute_contentkey} = \@conditions;
    }

    ##! 64: $query

    my $sth_attrib = CTX('dbi')->select(
        from => 'certificate_attributes',
        columns => [ 'attribute_contentkey', 'attribute_value' ],
        where => $query,
    );

    my $attrib;
    while (my $item = $sth_attrib->fetchrow_hashref) {
        ##! 64: $item
        my $key = $item->{attribute_contentkey};
        my $val = $item->{attribute_value};
        $attrib->{$key} //= [];
        push @{$attrib->{$key}}, $val;
    }
    ##! 32: $attrib

    return unless ($attrib);

    ##! 64: 'incoming tenant ' . ($params->tenant // '<undef>')
    if (my $tenant = $self->get_validated_tenant( $params->tenant )) {
        ##! 32: 'tenant ' . $tenant
        # check if tenant is in the result already
        my $owner_tenant;
        if ($attrib->{system_cert_tenant}) {
            $owner_tenant = $attrib->{system_cert_tenant}->[0];
        } else {
            $owner_tenant = CTX('api2')->get_certificate_tenant( identifier => $params->identifier );
        }
        $attrib = CTX('authentication')->tenant_handler()->certificate_attribute_filter( $tenant, $owner_tenant, $attrib );
    }

    return $attrib;
};

__PACKAGE__->meta->make_immutable;
