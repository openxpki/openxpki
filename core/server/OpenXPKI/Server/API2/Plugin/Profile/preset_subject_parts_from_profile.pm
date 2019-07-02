package OpenXPKI::Server::API2::Plugin::Profile::preset_subject_parts_from_profile;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::preset_subject_parts_from_profile

=head1 COMMANDS

=cut

use Template;
use Data::Dumper;

# Project modules
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

=cut
command "preset_subject_parts_from_profile" => {
    profile => { isa => 'AlphaPunct', required => 1, },
    fields  => { isa => 'ArrayRef', },
    style   => { isa => 'Str', },
    section => { isa => 'Str', },
    preset =>  { isa => 'HashRef', },
} => sub {
    my ($self, $params) = @_;

    die "Either 'fields' or 'style' must be specified"
     unless $params->has_fields || $params->has_style;

    my %args = (
        profile => $params->profile,
        section => $params->has_section ? $params->section : 'subject',
    );

    $args{style} = $params->style if ($params->has_style);
    $args{fields} = $params->fields if ($params->has_fields);

    # Load the field spec for the subject
    my $fields = $self->api->get_field_definition(%args);

    my $tt = Template->new();
    my $cert_subject_parts;
    FIELDS:
    foreach my $field (@{$fields}) {
        # Check if there is a preset template
        my $preset = $field->{preset};
        next FIELDS unless ($preset);

        # clonable field with iteration marker "X"
        my @val;
        if ($preset =~ m{ \A \s* (\w+)\.X \s* \z }xs) {
            my $comp = $1;
            ##! 32: 'Hashed DN Component ' . Dumper $hashed_dn{$comp}
            foreach my $v (@{$params->preset->{$comp}}) {
                ##! 16: 'clonable iterator value ' . $v
                push @val, $v if (defined $v && $v ne '');
            }

        # Fast path, copy from DN

        } elsif ($preset =~ m{ \A \s* (\w+)(\.(\d+))? \s* \z }xs) {
            my $comp = $1;
            my $pos = $3 || 0;
            my $val = $params->preset->{$comp}->[$pos];
            ##! 16: "Fixed dn component $comp/$pos: $val"
            if (defined $val && $val ne '') {
                @val = ($val);
            }
        # Should be a TT string
        } else {
            my $val;
            $tt->process(\$preset, $params->preset, \$val) || OpenXPKI::Exception->throw(
                message => 'Preset profile fields TT failed',
                params => { PROFILE => $params->profile, STYLE => $params->has_style ? $params->style : undef,
                    FIELD => $field, PATTERN => $preset, 'ERROR' => $tt->error() }
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
                $cert_subject_parts->{ $field->{id} } = \@val;
                CTX('log')->application()->debug("subject preset - field $field, pattern $preset, values " . join('|', @val));

            } else {
                $cert_subject_parts->{ $field->{id} } = $val[0];

                CTX('log')->application()->debug("subject preset - field $field, pattern $preset, value " . $val[0]);

            }
        }

    }

    ##! 32: 'Result ' . Dumper $cert_subject_parts
    return $cert_subject_parts;

};

__PACKAGE__->meta->make_immutable;
