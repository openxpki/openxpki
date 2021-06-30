package OpenXPKI::Server::API2::Plugin::Crypto::validate_ruleset;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::validate_ruleset

=head1 COMMANDS

=cut

use Data::Dumper;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );

=head2 validate_ruleset

Check if input data matches a defined ruleset.

Expects a hash with the params to validate and a hash with a ruleset.

The leafes of the rules can be either a list or a single item. The
special term I<_any> matches any value (even if the key is not set!)

For I<key_length> you can give a discret number or a range min:max,
borders are included. You can leave out the upper side (e.g. 1024:)
which will match any size above, to avoid a lower limit set it to "0"

The attribute I<digest_alg> has an expansion from I<sha2> to
I<sha224 sha256 sha384 sha512>.

Any other attributes will result in a "is contained in list" operation.

Return is a list with all parameter names that failed validation.

B<Parameters>

=over

=item * C<input> I<Hash>

the hash with the keys properties

=item * C<ruleset> I<Hash>

the hash with the rules as defined in the profile, the attribute
name (e.g. I<key_length>) must be the key of the first level.

=back

B<Example>

    validate_ruleset({
        input => { key_length => 512 }
        ruleset => {
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

command "validate_ruleset" => {
    input => { isa => 'HashRef', required => 1,  },
    ruleset => { isa => 'HashRef', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $input = $params->input;
    my $ruleset = $params->ruleset;

    ##! 16: 'Input ' . Dumper $input
    ##! 16: 'Rules ' . Dumper $ruleset

    my @error;

    ATTR:
    foreach my $attr (keys %{$ruleset}) {

        my $val = $input->{$attr} || '';

        my @expect = (!ref $ruleset->{$attr}) ? ($ruleset->{$attr}) : @{$ruleset->{$attr}};

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
            my @ranges = grep /\A_?(\d+):(\d*)\z/, @expect;
            ##! 32: 'Got ranges : ' . Dumper \@ranges
            foreach my $range (@ranges) {
                $range =~ m{\A_?(\d+):(\d*)\z};
                if ($val >= $1 && (!$2 || $val <= $2)) {
                    ##! 16: "Valid match found in range $val / $range"
                    next ATTR;
                }
            }
        }

        if ($attr eq 'digest_alg') {
            if (grep {$_ eq 'sha2'} @expect) {
                push @expect, ('sha224','sha256','sha384','sha512');
            }
        }

        ##! 32: "Validate param $attr, $val, " . Dumper \@expect
        if (!grep(/\A_?$val\z/, @expect)) {
            push @error, $attr;
        }
    }

    return \@error;
};


=head2 validate_key_params

Alias to validate_ruleset for backward compatibility, the input
parameters are mapped as is to the new method.

B<Parameters>

=over

=item * C<key_params> I<Hash>

=item * C<key_rules> I<Hash>

=cut
command "validate_key_params" => {
    key_params => { isa => 'HashRef', required => 1,  },
    key_rules => { isa => 'HashRef', required => 1, },
} => sub {
    my ($self, $params) = @_;
    return $self->api->validate_ruleset( input => $params->key_params, ruleset => $params->key_rules );
};

__PACKAGE__->meta->make_immutable;
