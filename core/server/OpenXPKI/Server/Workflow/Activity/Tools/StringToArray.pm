
package OpenXPKI::Server::Workflow::Activity::Tools::StringToArray;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Workflow::Exception qw(configuration_error);
use OpenXPKI::Serialization::Simple;
use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;

    my $context  = $workflow->context();
    my $params = $self->param();

    my $target_key = $self->param('target_key');
    if (!$target_key) {
        configuration_error('No target_key set in StringToArray');
    }

    my $ser  = OpenXPKI::Serialization::Simple->new();

    # we read the string from the parameter "value"
    my $val = $self->param('value');

    ##! 16: 'Value ' . $value

    return unless ($val);


    my $regex = $self->param('regex');
    $regex = '\s+' unless (defined $regex);

    my $modifier = $self->param('modifier') || '';
    $modifier =~ s/\s//g;
    if ($modifier =~ /[^alupimsx]/ ) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_VALIDATOR_REGEX_INVALID_MODIFIER",
            params => {
                MODIFIER => $modifier,
            },
        );
    }
    $modifier = "(?$modifier)" if ($modifier);
    $regex = qr/$modifier$regex/;

    ##! 16 : 'Seperator ' . $sep
    my @t = split($regex, $val);

    ##! 32: 'Split result ' . Dumper \@t
    $context->param( $target_key => $ser->serialize(\@t) );

    return 1;
}

1;


__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::StringToArray

=head1 Description

Trigger notifications using the configured notifcation backends.

=head2 Message

Specifiy the name of the message template to send using the I<message> parameter.

=head2 Additional parameters

To make arbitrary value available for the templates, you can specify additional
parameters to be mapped into the notififer. Example:

    <action name="I18N_OPENXPKI_WF_ACTION_TEST_NOTIFY1"
        class="OpenXPKI::Server::Workflow::Activity::Tools::Notify"
        message="csr_created"
        _map_fixed_value="a fixed value"
        _map_from_context="$my_context_key">
     </action>

The I<_map_> prefix is stripped, the remainder is used as key.
Values starting with a $ sign are interpreted as context keys.
