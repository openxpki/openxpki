package OpenXPKI::Server::Workflow::Activity::EST::GenerateCSRAttribute;

use warnings;
use strict;
use Data::Dumper;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use MIME::Base64 qw(encode_base64);

use base qw( OpenXPKI::Server::Workflow::Activity );

sub execute {

    my $self       = shift;
    my $workflow   = shift;
    my $context = $workflow->context();

    my $target_key = $self->param('target_key') || 'asn1';
    my $oidlist = $self->param('oidlist');

    my @lines = split(/\s+/, $oidlist);
    ##! 32: 'Lines ' . Dumper \@lines

    my $i = 1;
    my $source = "asn1 = SEQUENCE:seq_section\n[seq_section]\n";

    foreach my $line (@lines) {
        $source .= sprintf("field%01d = OID:%s\n", $i++, $line);
    }

    ##! 32: 'ASN1 conf ' . $source

    my $token = CTX('api')->get_default_token();
    my $asn1 = $token->command({
        COMMAND => 'asn1_genconf',
        DATA => $source });

    # return value is binary
    $context->param( $target_key => encode_base64($asn1) );
    return undef;
}

1;

__END__

=head1 OpenXPKI::Server::Workflow::Activity::EST::GenerateCSRAttribute;

Generate attribute list for the EST csrattrs command

=head1 Configuration

=head2 Parameters

=over

=item oidlist

Expects a newline seperated list of OIDs.

=item target_key

context item to write the (base64 encoded) result to, default is csrattr.

=back

=head2 Example

  generate_attributes:
    class: OpenXPKI::Server::Workflow::Activity::EST::GenerateCSRAttribute
    param:
      oidlist: |
        1.3.6.1.1.1.1.22
        emailAddress
        secp384r1
        sha384


