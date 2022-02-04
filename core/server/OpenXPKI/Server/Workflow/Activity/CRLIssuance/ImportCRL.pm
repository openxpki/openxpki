package OpenXPKI::Server::Workflow::Activity::CRLIssuance::ImportCRL;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Template;
use OpenXPKI::Debug;
use File::Temp;
use MIME::Base64;
use Workflow::Exception qw(configuration_error);

sub execute {

    ##! 1: 'start'

    my $self = shift;
    my $workflow = shift;

    my $data = $self->param('data');
    my $target_key = $self->param('target_key') || 'crl_serial';

    if ($data) {
        my %args =  ( data => $data );
        foreach my $key (qw(profile skip_duplicate nosigner)) {
            $args{$key} = $self->param($key) if ($self->param($key));
        }
        ##! 32: 'Importing with args ' . Dumper \%args
        my $crl = CTX('api2')->import_crl( %args );
        $workflow->context()->param( { $target_key => $crl->{crl_key} } );
    } else {
        $workflow->context()->param( { $target_key => undef } );
    }
    return 1;
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CRLIssuance::ImportCRL

=head1 Description

This activity can be used to import CRLs into the system. It should be
used for externally controlled realms only.

=head2 Activity Configuration

=over

=item data

Must hold the PEM encoded CRL to import, activity will return without error
if this is empty.

=item target_key

Name of context key to write the serial number of the imported CRL to.
Optional, default is crl_serial.

=item profile

Set thie profile for the imported CRL

=item skip_duplicate

Dont die if the CRL is already in the database

=item nosigner

Export as CRL that is not bound to a ca signer, mainly used for CRL
checking of external trust anchors. The issuer certificate must be
in the database (can be in any realm).

=back
