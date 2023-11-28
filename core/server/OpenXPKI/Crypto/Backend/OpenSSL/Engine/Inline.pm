package OpenXPKI::Crypto::Backend::OpenSSL::Engine::Inline;

use strict;
use warnings;
use English;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Engine::OpenSSL);

sub get_key_object
{
    my $self = shift;

    OpenXPKI::Exception->throw (
        message => "Unsupported key store",
        params => { KEY => $self->{KEY} }
    ) unless($self->get_key_store() eq "DATAPOOL");

    my $dp = CTX('api2')->get_data_pool_entry(
        namespace => 'sys.crypto.keys',
        key => $self->{KEY},
    );

    OpenXPKI::Exception->throw (
        message => "Unable to load key from datapool",
        params => { KEY => $self->{KEY} }
    ) unless ($dp && $dp->{value});

    my $buffer = $dp->{value};
    return Crypt::PK::RSA->new(\$buffer, $self->get_passwd() );
}


sub key_usable {

    my $self = shift;

    eval {
        $self->get_key_object();
    };
    if ($EVAL_ERROR) {
        # we could not get the password, so the key is not usable
        return 0;
    }

    return 1;

}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Engine::OpenSSL

=head1 Description

The real implementation is in OpenXPKI::Crypto::Backend::OpenSSL::Engine.
This engine is only a dummy to allow interface compliant usage of
the reference implementation. OpenXPKI::Crypto::Backend::OpenSSL::Engine
includes a basic specification of every function and an
implmentation which bases on OpenSSL software keys.
