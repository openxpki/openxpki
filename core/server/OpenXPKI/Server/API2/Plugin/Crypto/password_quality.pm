package OpenXPKI::Server::API2::Plugin::Crypto::password_quality;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::password_quality

=head1 COMMANDS

=cut

use Data::Dumper;

# Project modules
use OpenXPKI::Server::API2::Plugin::Crypto::password_quality::Validate;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );

=head2 password_quality

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
command "password_quality" => {
    password => { isa => 'Str', required => 1, },
    checks => { isa => 'ArrayRef', },
    max_len => { isa => 'Int', },
    min_len => { isa => 'Int', },
    min_diff_chars => { isa => 'Int', },
    sequence_len => { isa => 'Int', },
    min_entropy => { isa => 'Int', },
    min_dict_len => { isa => 'Int', },
    dictionaries => { isa => 'ArrayRef', },
    min_different_char_groups => { isa => 'Int', },
} => sub {
    my ($self, $params) = @_;

    # Turn $params object into hash
    # FIXME Move this code into a new superclass for parameter objects
    my %params_hash = ();
    my $meta = $params->meta;
    for my $attr ($meta->get_attribute_list) {
        $params_hash{$attr} = $params->$attr if $meta->get_attribute($attr)->has_value($params);
    }

    # Pass parameters to worker class 1:1
    # ("password" will be passed too, but Moose ignores superfluous parameters)
    my $validator = OpenXPKI::Server::API2::Plugin::Crypto::password_quality::Validate->new(
        log => CTX('log')->application,
        %params_hash,
    );

    my $is_valid = $validator->is_valid($params->password);

    return [] if $is_valid;
    return [ $validator->error_messages ];
};

__PACKAGE__->meta->make_immutable;
