package OpenXPKI::Server::Workflow::Activity::Tools::CRLExport;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Template;
use OpenXPKI::Debug;
use Data::Dumper;
use File::Temp;
use Workflow::Exception qw(configuration_error);


sub execute {

    ##! 1: 'start'

    my $self = shift;
    my $workflow = shift;

    my $context = $workflow->context();

    my $issuer_identifier = $self->param('issuer_identifier');
    my $target_key = $self->param('target_key') || 'crl_export';
    my $prefix = $self->param('prefix') || 'crl_';
    my $format = $self->param('format') || 'PEM';

    if ($format eq 'HASH') {
        my $crl = CTX('api2')->get_crl( issuer_identifier => $issuer_identifier, format => 'DBINFO' );
        $context->param({
            crl_serial => $crl->{crl_key},
            crl_number => $crl->{crl_number},
            items => $crl->{items},
            $prefix.'last_update' => $crl->{last_update},
            $prefix.'next_update' => $crl->{next_update},
            $prefix.'publication_date' => $crl->{publication_date},
        });
    } elsif ($format eq 'PEM') {
        my $pem = CTX('api2')->get_crl( issuer_identifier => $issuer_identifier, format => 'PEM' );
        $context->param( $target_key  => $pem );
    } elsif ($format eq 'DER') {
        configuration_error('You can not export binary data to a non-volatile context item') if ($target_key !~ /^_/);
        my $der = CTX('api2')->get_crl( issuer_identifier => $issuer_identifier, format => 'DER' );
        $context->param( $target_key  => $der );
    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::CRLExport

=head1 Description

Export the latest CRL for a given issued to the context. Can export
PEM/DER encoded CRL or metadata.

=head1 Configuration

=head2 Activity parameters

=over

=item issuer_identifier

The issuer to get the CRL for.

=item format

=over

=item PEM

Export the CRL in PEM encoding to the given I<target_key>

=ITEM DER

Export the CRL as binary data (DER) to the given I<target_key>, the
target key must start with an underscore (volatile context item).

=item HASH

Write the metadata from the crl table into mulitple context items, the
prefix can be set with I<prefix>, the default is I<crl_>.

Items populated:

=over

=item crl_serial

=item crl_number

=item ${prefix}items

=item ${prefix}last_update, ${prefix}next_update, ${prefix}publication_date

The date from the CRL as epoch (integer).

=back

=back

=item target_key, optional

The context key to write the result to, default is I<crl_export>.

=item prefix

Prefix to add to the context keys for format I<HASH>.

=back

