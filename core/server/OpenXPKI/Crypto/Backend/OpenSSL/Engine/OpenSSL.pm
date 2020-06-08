package OpenXPKI::Crypto::Backend::OpenSSL::Engine::OpenSSL;

use strict;
use warnings;
use English;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Engine);

sub key_usable {

    my $self = shift;

    eval {
        $self->get_passwd();
    };
    if ($EVAL_ERROR) {
        # we could not get the password, so the key is not usable
        return 0;
    }

    if ($self->get_key_store() eq "DATAPOOL") {
        ##! 16: 'Get key from datapool ' . $self->{KEY}
        if ($self->{'tmp_keyfile'} && -r $self->{'tmp_keyfile'}) {
            return 1;
        }

        my $dp = CTX('api2')->get_data_pool_entry(
            namespace => 'sys.crypto.keys',
            key => $self->{KEY},
        );
        return ($dp && $dp->{value});
    }

    return (-r $self->{KEY});

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
