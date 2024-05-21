package OpenXPKI::Client::API::Command;
use OpenXPKI -role;

with 'OpenXPKI::Role::Logger';

=head1 NAME

OpenXPKI::Client::API::Command

=head1 SYNOPSIS

Base role for all implementations handled by C<OpenXPKI::Client::API>.

=cut

sub _build_hash_from_payload ($self, $param, $allow_bool = 0) {
    return {} unless $param->has_payload;

    my %params;
    foreach my $arg ($param->payload->@*) {
        my ($key, $val) = split('=', $arg, 2);
        $val = 1 if (not defined $val and $allow_bool);
        next unless defined $val;
        if ($params{$key}) {
            if (not ref $params{$key}) {
                $params{$key} = [$params{$key}, $val];
            } else {
                push @{$params{$key}}, $val;
            }
        } else {
            $params{$key} = $val;
        }
    }
    return \%params;
}

1;
