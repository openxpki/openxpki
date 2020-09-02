package OpenXPKI::Server::API2::Plugin::Crypto::validate_password;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::validate_password

=head1 COMMANDS

=cut

use Data::Dumper;

# Project modules
use OpenXPKI::Server::API2::Plugin::Crypto::validate_password::Validate;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );

=head2 validate_password

Check if the given password passes certain quality checks.

Returns undef on sucessful validation or an ArrayRef with error messages of failed checks.

B<Parameters>

=over

=item * C<xxx> I<xxx> - blah

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
command "validate_password" => {
    password => { isa => 'Str', required => 1, },
    checks => { isa => 'ArrayRef', },
    max_len => { isa => 'Int', },
    min_len => { isa => 'Int', },
    min_diff_chars => { isa => 'Int', },
    sequence_len => { isa => 'Int', },
    min_dict_len => { isa => 'Int', },
    dictionaries => { isa => 'ArrayRef', },
    min_different_char_groups => { isa => 'Int', },
} => sub {
    my ($self, $params) = @_;

    my $validator = OpenXPKI::Server::API2::Plugin::Crypto::validate_password::Validate->new(
        log => CTX('log')->application,
        $params->has_max_len ? (max_len => $params->max_len) : (),
        $params->has_min_len ? (min_len => $params->min_len) : (),
        $params->has_min_diff_chars ? (min_diff_chars => $params->min_diff_chars) : (),
        $params->has_sequence_len ? (sequence_len => $params->sequence_len) : (),
        $params->has_min_dict_len ? (min_dict_len => $params->min_dict_len) : (),
        $params->has_dictionaries ? (dictionaries => $params->dictionaries) : (),
        $params->has_min_different_char_groups ? (min_different_char_groups => $params->min_different_char_groups) : (),
    );

    my $is_valid = $validator->is_valid($params->password);

    return [] if $is_valid;
    return [ $validator->error_messages ];
};

__PACKAGE__->meta->make_immutable;
