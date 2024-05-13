package OpenXPKI::Server::API2::Plugin::tenant_handler;
use OpenXPKI -plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::tenant_handler

=cut


# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;


=head1 COMMANDS

=head2 can_access_tenant

Check if the given tenant can be accessed by the current session user.

Return a literal 0 or 1 whether the user is allowed. Returns undef if a
tenant was given but the current user has no tenant handler set.

B<Parameters>

=over

=item * C<tenant> L<Tenant|OpenXPKI::Types/Tenant> - tenant

=back

=cut
command "can_access_tenant" => {
    tenant => { isa => 'Tenant', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $handler = CTX('authentication')->tenant_handler();

    if ($handler) {
        return $handler->check_access( CTX('session')->data->tenants, $params->tenant );
    } else {
        # if no handler is set, the empty tenant "" (or "0") is allowed
        return 1 unless $params->tenant;

        # return undef to indicate missing evaluation
        return;
    }
};

=head2 get_primary_tenant

Get the primary tenant based on the current session information.

If a tenant hander is defined for the current role, the handlers
get_primary_tenant method is called with the content of the I<tenant>
attribute from this session.

Returns I<undef> if the role has no tenant handler set, returns the
name of the tenant if the handler can determine one. Throws an
exception, if the handler can not fullfil the request.

=cut

command "get_primary_tenant" => {
} => sub {
    my ($self, $params) = @_;

    ##! 1: 'start'

    if (CTX('session')->data->has_primary_tenant()) {
        ##! 32: 'Pulling primary tenant from session'
        return CTX('session')->data->primary_tenant();
    }

    if (!CTX('authentication')->has_tenant_handler()) {
        ##! 32: 'No handler - set primary tenant to undef'
        CTX('session')->data->primary_tenant( undef );
        return;
    }

    my $handler = CTX('authentication')->tenant_handler();

    my $tenant = $handler->get_primary_tenant( CTX('session')->data->tenants );
    OpenXPKI::Exception->throw (
        message => "Unable to get primary tenant for this role",
        params => { tenants => CTX('session')->data->tenants, handler => $handler }
    ) unless ($tenant);

    ##! 32: "Got primary tenant handler: $tenant - update session"
    CTX('session')->data->primary_tenant( $tenant );

    return $tenant;

};

=head2 get_certificate_tenant

Get the tenant owner of a certificate.

Returns the content of the system_cert_tenant attribute or undef if
none is found.

B<Parameters>

=over

=item * C<identifier> I<Str> - certificate identifier

=back

=cut

command "get_certificate_tenant" => {
    identifier => { isa => 'Str', required => 1, },
} => sub {
    my ($self, $params) = @_;
    ##! 1: 'start'

    my $db_owner = CTX('dbi')->select_one(
        from => 'certificate_attributes',
        columns => [ 'attribute_value' ],
        where =>  { identifier => $params->identifier, attribute_contentkey => 'system_cert_tenant' },
    );
    ##! 32: $db_owner
    return unless ($db_owner);

    return $db_owner->{attribute_value};
};

=head2 get_workflow_tenant

Returns the content of the workflows tenant attribute or undef if
none is found.

B<Parameters>

=over

=item * C<id> I<Int> - workflow ID

=back

=cut

command "get_workflow_tenant" => {
    id => { isa => 'Int', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $result = CTX('dbi')->select_one(
        from => 'workflow_attributes',
        columns => [ 'attribute_value' ],
        where => { attribute_contentkey => 'tenant', workflow_id => $params->id },
    );

    return unless $result;
    return $result->{attribute_value};
};

__PACKAGE__->meta->make_immutable;
