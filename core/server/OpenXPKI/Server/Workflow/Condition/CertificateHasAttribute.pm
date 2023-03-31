package OpenXPKI::Server::Workflow::Condition::CertificateHasAttribute;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

use Data::Dumper;

sub _evaluate {

    ##! 1: 'start'
    my ( $self, $workflow ) = @_;

    my $log = CTX('log')->application();
    my $context  = $workflow->context();
    ##! 64: 'context: ' . Dumper($context)

    my $attribute = $self->param('attribute');
    my $condition = $self->param('condition') || 'defined';
    my $value = $self->param('value') // '';
    ##! 32: "$attribute / $condition / $value"

    if (!$attribute || $attribute =~ m{\W}) {
        configuration_error('Attribute name must be given and must not contain any non-word characters');
    }

    my $cert_identifier = $self->param('cert_identifier');
    $cert_identifier = $context->param('cert_identifier') unless($cert_identifier);

    if (!defined $cert_identifier ) {
        configuration_error('You need to have cert_identifier in context or set it via the parameters');
    }

    my $res =  CTX('api2')->get_cert_attributes(
        identifier => $cert_identifier,
        attribute => $attribute,
        tenant => '',
    );

    if (!defined $res) {
        ##! 16: 'not defined'
        $log->debug("CertificateAttribute condition failed - no values found");
        condition_error('CertificateAttribute condition failed');
    }

    ##! 64: $res
    $log->trace("CertificateHasAttribute $attribute got result " . Dumper $res) if $log->is_trace;
    if ($condition eq 'defined') {
        $log->debug('CertificateHasAttribute is defined');
        return 1;
    }

    configuration_error('CertificateAttribute has no value for comparison defined') unless($value ne '');

    my @values = @{$res->{$attribute}};
    if ($condition eq 'is_value') {
        condition_error('CertificateAttribute condition is_value failed (more then one item)')
            if (@values > 1);

        condition_error('CertificateAttribute condition is_value does not match')
            if ($values[0] ne $value);

        $log->debug('CertificateHasAttribute is_value passed');
        return 1;
    }

    if ($condition eq 'has_value') {
        if (grep { $_ eq $value } @values) {
            $log->debug('CertificateHasAttribute contains value ' . $value);
            return 1;
        }
        condition_error('CertificateAttribute condition has_value failed');
    }

    condition_error('CertificateAttribute unsupported condition');

    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CertificateHasAttribute

=head1 SYNOPSIS

=head1 DESCRIPTION

This condition checks whether

=head2 Activity Parameters

=over

=item attribute

Name of the attribute to look up, wildcards are not allowed!

=item cert_identifier

Certificate to look up, if not given uses the value from the context.

=item condition

The condition that the attribute must fulfill

=over

=item defined (default)

The certificate has at least one entry for the attribute given.

=item is_value

The certificate has exaclty one item and this matches the given value.

=item has_value

The certificate has at least one item that matches the given value.

=back

=item value

The value to match the attributes value (full string match).
Ignored when I<condition> is set to I<defined>.

=back
