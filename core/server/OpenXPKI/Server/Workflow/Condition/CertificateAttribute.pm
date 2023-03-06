package OpenXPKI::Server::Workflow::Condition::CertificateAttribute;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition::CertificateHasAttribute );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

sub _evaluate {
    my $self = shift;
    CTX('log')->deprecated()->error('Please rename O::S::W::Condition::CertificateAttribute to CertificateHasAttribute');
    $self->SUPER::_evaluate(@_);
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CertificateAttribute

=head1 DESCRIPTION

This class is deprecated and should no longer be used.
Use OpenXPKI::Server::Workflow::Condition::CertificateB<Has>Attribute.