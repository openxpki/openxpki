package OpenXPKI::Server::Workflow::Condition::WFHash;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Condition );

use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Workflow::WFObject::WFHash;


sub _evaluate {

    my ( $self, $wf ) = @_;
    my $context = $wf->context();

    my $hash_name = $self->param('hash_name');

    my $hash = OpenXPKI::Server::Workflow::WFObject::WFHash->new({
        workflow => $wf,
        context_key => $hash_name,
    });

    my $key =  $self->param('hash_key');

    configuration_error('No key defined') unless($key);

    my $val = $hash->valueForKey($key);

    ##! 16: ' Key: ' . $key . ' - Value ' . Dumper ( $val )

    my $condition = $self->param('condition');

    CTX('log')->application()->debug("Testing if WFHash ". $hash_name ." key $key is " . $condition);


    if ($condition eq 'key_defined') {
       if (defined $val) {
           ##! 16: ' Entry is defined '
           return 1;
       }
       ##! 16: ' Entry not defined '
       condition_error 'Condition wfhash key '.$key.' is not defined';
    } elsif ($condition eq 'key_nonempty') {
       if (defined $val && $val) {
           ##! 16: ' Entry not empty '
           return 1;
       }
       ##! 16: ' Entry is empty '
       condition_error 'Condition wfhash key '.$key.' is empty';
    } elsif ($condition eq 'is_value') {
        my $value = $self->param('value') // '';
        if (defined $val && $val eq $value) {
            ##! 16: ' Entry matches value ' . $value
            return 1;
        }
         ##! 16: ' Entry does not match value ' . $value
        condition_error 'Condition wfhash key '.$key.' does not match expected value ';
    } else {
        configuration_error
            "Invalid condition " . $condition . " in " .
            "declaration of condition " . $self->name();
    }
}

1;
__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::WFHash

=head1 SYNOPSIS

  cert_exists:
     class: OpenXPKI::Server::Workflow::Condition::WFHash
     param:
        hash_name: cert_map
        condition: key_defined
        hash_key: key_to_check


=head1 DESCRIPTION

Allows for checks on a hash stored as a workflow context parameter.

=head2 Configuration

=over

=item hash_name

The name of the workflow context parameter containing the hash to be used

=item condition

The following conditions are supported:

=over 8

=item key_defined

Condition is true if the key has a value.
The key must be given with the "key" param.

=item key_nonempty

Condition is true if the key has a non-empty value
The key must be given with the "key" param.

=item is_value

Condition is true if the key has a non-empty value
The key must be given with the "key" param.

=back

=item hash_key

Name of the key to check

=item value

value to check against when condition is set to I<is_value>.

=back
