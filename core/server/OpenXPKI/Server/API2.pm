package OpenXPKI::Server::API2;
use OpenXPKI -class;

with 'OpenXPKI::Base::API::APIRole';

# required by OpenXPKI::Base::API::APIRole
sub namespace { __PACKAGE__. '::Plugin' }

=head1 NAME

OpenXPKI::Server::API2 - Standardized internal and external access to sensitive
functions

=head1 DESCRIPTION

For details see L<OpenXPKI::Base::API::APIRole>.

=cut

# required by OpenXPKI::Base::API::APIRole
sub handle_dispatch_error ($self, $err) {
    my $msg = $err;
    if (blessed($err)) {
        if ($err->isa("OpenXPKI::Exception")) {
            $err->rethrow;
        }
        elsif ($err->isa("Moose::Exception")) {
            $msg = $err->message;
        }
    }
    OpenXPKI::Exception->throw(
        message => "Error while executing API command",
        params => {
            error => $msg,
            caller => sprintf("%s:%s", ($self->my_caller(1))[1,2]),
        },
    );
}

__PACKAGE__->meta->make_immutable;
