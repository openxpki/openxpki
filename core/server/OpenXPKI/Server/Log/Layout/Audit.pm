package OpenXPKI::Server::Log::Layout::Audit;
use OpenXPKI qw( -class -nonmoose );

extends 'Log::Log4perl::Layout::PatternLayout';

use Log::Log4perl;

sub render {
    my $self = shift;
    my($message, $category, $priority, $caller_level) = @_;

    # args is a two element list,
    # the first item is the message string
    # the second one is a hashref with the parameters
    if (ref $message eq 'ARRAY') {

        # create a copy to not destroy the message for others
        my @input = $message->@*;
        my $msg = shift @input;
        my %param;
        # old format - params as hash
        if (scalar @input == 1) {
            %param = $input[0]->@*;
            CTX('log')->deprecated()->warn('deprecated audit log call with message ' . $msg);

        # new format - list of key/value pairs
        } elsif (scalar @input) {
            %param = @input;

        }

        my @keys = sort keys %param;
        if (@keys) {
            $msg .= '|'. join("|", map { $_.'='.($param{$_} // 'undef') } @keys);
        }

        $message = $msg;
    }

    $caller_level++;
    return $self->SUPER::render( "$message", $category, $priority, $caller_level );
};

__PACKAGE__->meta->make_immutable;

=head1 Name

OpenXPKI::Server::Log::Layout::Audit

=head1 Description

The audit log calls used in OpenXPKI pass relevant parameters along with the
message which is not compatible with the default message handlers. This layout
class provides the glue to create a string from this hash and write it into a
message string finally.

=head1 Example

The syntax inside the code looks like:

    CTX('log')->audit()->warn('Private Key used',
        pkey => 'IssuerCA1',
        operation => 'Signature'
    );

When using this module, this becomes:

    Private Key used|operation=Signature|pkey=IssuerCA1

Keys are sorted, key/value pairs are joined using "=", the keypairs are
joined using the Pipe "|".

The class also support the legacy format where the paramaters are passed as
hash in the second argument.