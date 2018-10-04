package OpenXPKI::Server::Log::Layout::Audit;

use Moose;
use Log::Log4perl;
use Data::Dumper;

extends 'Log::Log4perl::Layout::PatternLayout';

sub render {
    my $self = shift;
    my($message, $category, $priority, $caller_level) = @_;

    # args is a two element list,
    # the first item is the message string
    # the second one is a hashref with the parameters
    if (ref $message eq 'ARRAY') {
        my $param = $message->[1];
        $message = $message->[0];
        if ($param) {
            my @keys = sort keys %{$param};
            $message .= '|'. join("|", map { $_.'='.($param->{$_} // 'undef') } @keys);
        }
    }

    $caller_level++;
    return $self->SUPER::render( $message, $category, $priority, $caller_level );
};

1;

=head1 Name

OpenXPKI::Server::Log::Layout::Audit

=head1 Description

The audit log calls used in OpenXPKI pass relevant parameters as hash
along with the message which is not compatible with the default message
handlers. This layout class provides the glue to create a string from
this hash and write it into a message string finally.

=head1 Example

The syntax inside the code looks like:

    CTX('log')->audit()->warn('Private Key used', {
        pkey => 'IssuerCA1',
        operation => 'Signature'
    });

When using this module, this becomes:

    Private Key used|operation=Signature|pkey=IssuerCA1

Keys are sorted, key/value pairs are joined using "=", the keypairs are
joined using the Pipe "|".
