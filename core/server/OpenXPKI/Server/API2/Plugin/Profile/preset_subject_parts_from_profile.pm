package OpenXPKI::Server::API2::Plugin::Profile::preset_subject_parts_from_profile;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::preset_subject_parts_from_profile

=head1 COMMANDS

=cut

use Template;
use Data::Dumper;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Plugin::Profile::Util;

=head2 preset_subject_parts_from_profile

Generate cert_subject_parts hash by parsing a profiles preset attributes

B<Parameters>

=over

=item * C<profile> I<Str> - certificate profile name, required

=item * C<fields> I<ArrayRef> - list of field names to query, default: all fields
of the given style

=item * C<style> I<Bool> - profile style to query, required if C<fields> is not specified

=item * C<section> I<Str> - ui section (only used if C<style> was specified), default: "subject"

=item * C<preset> I<HashRef>

=back

The parser knows four different notations for the preset rules.

=over

=item clonable field word.X

Expects $param->{word} to be an array and creates one field item for
each value. The I<X> is a literal character.

=item DN component rdn / rdn.n

Create a field using the n-th value of the dn component I<rdn>. If I<n>
is not given the first component is used. E.g. to set a field to the
commonName of a used CSR write I<CN> or I<CN.0>. To use the second
occurence of "organizational unit" write I<OU.1>.

The list of supported RDNs is I<C|ST|O|OU|CN|DC|L|UID|SN|GN|serialNumber>.

=item additional data word.key

If additional key/value data was passed as input, e.g. the userinfo hash
you can access those items writing e.g. I<userinfo.email>. To avoid any
ambigouties the section name must be lowercase and match the key of the
hash in the input data, the latter key can use any word character.

=item template

If none of the above rules is matched, the string is handed over to
template toolkit using the preset hash as variable input. If the field
is clonable, the result is split at the pipe symbol and a field is added
for each non-empty item.

=back

=cut
command "preset_subject_parts_from_profile" => {
    profile => { isa => 'AlphaPunct', required => 1, },
    fields  => { isa => 'ArrayRef', },
    style   => { isa => 'Str', },
    section => { isa => 'Str', default => 'subject' },
    preset =>  { isa => 'HashRef', },
} => sub {
    my ($self, $params) = @_;

    die "Either 'fields' or 'style' must be specified"
     unless $params->has_fields || $params->has_style;

    ##! 16: "Preset values = " . Dumper $params->preset

    my %args = (
        profile => $params->profile,
        section => $params->section,
    );

    $args{style} = $params->style if ($params->has_style);
    $args{fields} = $params->fields if ($params->has_fields);

    # Load the field spec for the subject
    my $fields = $self->api->get_field_definition(%args);

    my $tt = Template->new();
    my $cert_subject_parts;
    FIELDS:
    foreach my $field (@{$fields}) {
        ##! 16: "Field = " . Dumper $field
        # Check if there is a preset template
        my $preset = $field->{preset};
        next FIELDS unless ($preset);

        # clonable field with iteration marker "X"
        my @val;
        if ($preset =~ m{ \A \s* (\w+)\.X \s* \z }xs) {
            my $comp = $1;
            ##! 16: "Clonable field $comp"
            ##! 64: $params->preset->{$comp}
            next FIELDS unless (ref $params->preset->{$comp} eq 'ARRAY');
            foreach my $v (@{$params->preset->{$comp}}) {
                ##! 16: 'clonable iterator value ' . $v
                push @val, $v if (defined $v && $v ne '');
            }

        # Fast path, copy from DN
        } elsif ($preset =~ m{ \A \s* (C|ST|O|OU|CN|DC|L|UID|SN|GN|serialNumber)(\.(\d+))? \s* \z }xs) {
            my $comp = $1;
            my $pos = $3 || 0;
            my $val = $params->preset->{$comp}->[$pos];
            ##! 16: "Fixed dn component $comp/$pos: $val"
            if (defined $val && $val ne '') {
                @val = ($val);
            }

        # something like "userinfo.email", matches only lowercase, letter only
        # first parts to avoid conflicts with DN components
        } elsif ($preset =~ m{ \A \s* ([a-z]+)\.(\w+) \s* \z }xs) {
            my $sect = $1;
            my $comp = $2;
            ##! 16: "Extra info: $sect -> $comp"
            next FIELDS unless (ref $params->preset->{$sect} eq 'HASH');
            my $val = $params->preset->{$sect}->{$comp};
            if (defined $val && $val ne '') {
                @val = ($val);
            }
        # Should be a TT or fixed string
        } else {
            my $val;
            $tt->process(\$preset, $params->preset, \$val)
                or OpenXPKI::Exception->throw(
                    message => 'Preset profile fields TT failed',
                    params => {
                        PROFILE => $params->profile,
                        STYLE => $params->has_style ? $params->style : undef,
                        FIELD => $field,
                        PATTERN => $preset,
                        ERROR => $tt->error(),
                    }
                );

            ##! 16: "Template result: $val"
            # cloneable fields cn return multiple values using a pipe as seperator
            if ($field->{clonable} && ($val =~ /\|/)) {
                @val = split /\|/, $val;
                @val = grep { defined $_ && ($_ =~ /\S/) } @val;
            } elsif (defined $val && $val ne '') {
                @val = ($val);
            }
        }

        ##! 16: 'Result ' . Dumper \@val
        if (scalar @val) {
            if ($field->{clonable}) {
                $cert_subject_parts->{ $field->{name} } = \@val;
                CTX('log')->application()->debug("subject preset - field $field, pattern $preset, values " . join('|', @val));

            } else {
                $cert_subject_parts->{ $field->{name} } = $val[0];

                CTX('log')->application()->debug("subject preset - field $field, pattern $preset, value " . $val[0]);

            }
        }

    }

    ##! 32: 'Result ' . Dumper $cert_subject_parts
    return $cert_subject_parts;

};

__PACKAGE__->meta->make_immutable;
