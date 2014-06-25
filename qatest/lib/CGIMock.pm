package CGIMock;

use Moose;

has data => (
    is => 'rw',
    isa => 'HashRef',
    default => sub{ return {} }
);

sub param {

    my $self = shift;
    my $name = shift;

    if ($name) {
        my $val = $self->data()->{$name};
        if (ref $val eq 'ARRAY') {
            return @{$val};
        }
        return $val;
    }
    return $self->data();

}

sub header {}
sub cookie {}

1;