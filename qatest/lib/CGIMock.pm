package CGIMock;

use Moose;
use Data::Dumper;

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
            warn "param in list context is deprecated - use multi_param";
            return @{$val};
        }
        return $val;
    }
    if (wantarray) {
        return keys %{$self->data()};
    }
    return $self->data();

}

sub multi_param {

    my $self = shift;
    my $name = shift;

    if (!wantarray) {
        die "multi_param must not be used outside list context";
    }

    if ($name) {
        my $val = $self->data()->{$name};
        if (!$val) { return (); }
        if (ref $val ne 'ARRAY') {
            return ($val);
        }
        return @{$val};
    }
    return keys %{$self->data()};
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

sub request_method {

    # always return POST to allow retrival of the action parameter
    return 'POST';

}

sub header {}
sub cookie {}
sub http {  return 1; }

1;