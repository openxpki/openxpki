package OpenXPKI::Server::API2::Plugin::Crypto::validate_key_params;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::validate_key_params

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );

=head2 validate_key_params

Check if all given key params match the defined rules.

Expects a hash with the current key params and a hash with the key
definition as defined in the profile section.

Return is a list with all parameter names that failed validation.

B<Parameters>

=over

=item * C<key_params> I<Hash> - the hash with the keys properties

=item * C<key_rules> I<Hash>  - the hash with the rules for all as defined in the
                               profile (algorithm is the key of the first level)

=back

B<Example>

    validate_key_params({
        key_params => { key_length => 512 }
        key_rules => {
            key_length =>  [
                _1024, # explicit length, hidden in UI
                2048,  # explicit length, shown in UI selectors
                _2048:8192 # allowed range, hidden in UI
            ]
        }}
    })

Will result in

   [ key_length ]

=cut
command "validate_key_params" => {
    key_params => { isa => 'HashRef', required => 1,  },
    key_rules => { isa => 'HashRef', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $key_params = $params->key_params;
    my $key_rules = $params->key_rules;

    my @error;

    ATTR:
    foreach my $attr (keys %{$key_rules}) {

        my $val = $key_params->{$attr} || '';

        my @expect = @{$key_rules->{$attr}};

        if (grep(/\A_any\z/, @expect)) {
            next ATTR;
        }

        # resolve ambigous curve names for NIST P-192/256
        if ($attr eq 'curve_name') {
            if (grep(/prime192v1/, @expect)) {
                push @expect, 'secp192r1';
            }
            if (grep(/prime256v1/, @expect)) {
                push @expect, 'secp256r1';
            }
        }

        # handle ranges for key_length
        if ($attr eq 'key_length') {
            my @ranges = grep /\A_?(\d+):(\d+)\z/, @expect;
            ##! 32: 'Got ranges : . Dumper \@ranges
            map {
                $_ =~ m{\A_?(\d+):(\d+)\z};
                if ($val > $1 && $val < $2) {
                    ##! 16: 'Valid match found in range $val / $_'
                    next ATTR;
                }
            } @ranges;
        }

        ##! 32: "Validate param $attr, $val, " . Dumper \@expect
        if (!grep(/\A_?$val\z/, @expect)) {
            push @error, $attr;
        }
    }

    return \@error;
};

__PACKAGE__->meta->make_immutable;
