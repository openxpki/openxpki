package OpenXPKI::Crypto::Token;
use OpenXPKI -class;

# required for the "usable" check of the current tokenmanager API
sub login {

    my $self = shift;
    OpenXPKI::Exception->throw(
        message => 'Unable to login token - secret group is not complete'
    ) unless ($self->_secret->is_complete);

    return 1;
}

sub online {

    my $self = shift;
    return 1;

}

1;

=head1 OpenXPKI::Crypto::Token

Base class for the new token layer