package OpenXPKI::Server::Workflow::Activity::NICE::RenewCertificate;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Activity );

sub execute {

    OpenXPKI::Exception->throw(
        message => 'NICE::RenewCertificate is depreacted - please use NICE::IssueCertificate instead',
    );
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::RenewCertificate

=head1 Description

Deprecated / Removed - please use IssueCertificate and set
the renewal_cert_identifier paramater
