package CGIMock;

use Moose;

has data => (
    is => 'rw',
    isa => 'HashRef',
    default => sub{ return {} }
);

has url_data => (
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
    if (wantarray) {
        return keys %{$self->data()};    
    }
    return $self->data();

}

sub url_param {

    my $self = shift;
    my $name = shift;

    if ($name) {
        my $val = $self->url_data()->{$name};
        if (ref $val eq 'ARRAY') {
            return @{$val};
        }
        return $val;
    }
    if (wantarray) {
        return keys %{$self->data()};    
    }
    return $self->url_data();

}

sub header {}
sub cookie {}
sub http {  return 1; }

1;