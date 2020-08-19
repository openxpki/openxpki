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

    my %query;
    if (my $crl_serial = $self->param('crl_serial')) {
        ##! 32: 'Use crl_serial ' . $crl_serial
        $query{crl_serial} = $crl_serial;
    }
    elsif (my $issuer_identifier = $self->param('issuer_identifier')) {
        ##! 32: 'Use issuer_identifier ' . $issuer_identifier
        $query{issuer_identifier} = $issuer_identifier;
    }
    else {
        configuration_error('Either crl_serial or issuer_identifier must be given');
    }

    if (my $crl_profile = $self->param('crl_profile')) {
        ##! 32: 'Use profile ' . $crl_profile
        $query{profile} = $crl_profile;
    }

    my $target_key = $self->param('target_key') || 'crl_export';
    my $prefix = $self->param('prefix') || 'crl_';
    my $format = $self->param('format') || 'PEM';

    if ($format eq 'HASH') {
        my $crl = CTX('api2')->get_crl( %query, format => 'DBINFO' );
        ##! 64: $crl
        $context->param({
            crl_serial => $crl->{crl_key},
            crl_number => $crl->{crl_number},
            items => $crl->{items},
            $prefix.'last_update' => $crl->{last_update},
            $prefix.'next_update' => $crl->{next_update},
            $prefix.'publication_date' => $crl->{publication_date},
        });
    } elsif ($format eq 'PEM') {
        my $pem = CTX('api2')->get_crl( %query, format => 'PEM' );
        ##! 128: $pem
        $context->param( $target_key  => $pem );
    } elsif ($format eq 'DER') {
        configuration_error('You can not export binary data to a non-volatile context item') if ($target_key !~ /^_/);
        my $der = CTX('api2')->get_crl( %query, format => 'DER' );
        $context->param( $target_key  => $der );
    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::CRLExport

=head1 Description

Export CRL to the context, can use a CRL by its serial number or get the
latest one for a given issuer.

Export format is PEM/DER encoded CRL or metadata.

=head1 Configuration

=head2 Activity parameters

=over

=item crl_serial

The crl serial number (database key) to export

=item issuer_identifier

Determine the latest CRL for this issuer, mutually exclusive to crl_serial

=item crl_profile

Export a crl that has a profile assigned, must also be given when using
crl_serial on such a crl!

=item format

=over

=item PEM

Export the CRL in PEM encoding to the given I<target_key>

=item DER

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

Prefix to add to the context keys for format I<HASH>. Default is I<crl_>.

=back

