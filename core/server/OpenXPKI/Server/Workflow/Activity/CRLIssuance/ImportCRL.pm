package OpenXPKI::Server::Workflow::Activity::CRLIssuance::ImportCRL;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Template;
use OpenXPKI::Debug;
use Data::Dumper;
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
        my $crl = CTX('api')->import_crl({ DATA => $data });
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

=back
