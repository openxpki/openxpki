package OpenXPKI::Server::API2::Plugin::Profile::render_templates;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::render_templates

=head1 COMMANDS

=cut

# CPAN modules
use Template;

# Project modules
use OpenXPKI::Server::Context qw( CTX );

has tt => (
    is => 'rw',
    isa => 'Template',
    default => sub { Template->new },
);

=head2 render_subject_from_template

Renders the certificate subject by using the text template as defined in the
certificate profile (C<profile.XXX.style.XXX.subject.dn>) and the given variables.

The result might be empty.

B<Parameters>

=over

=item * C<profile> I<Str> - certificate profile, required

=item * C<style> I<Str> - profile substyle, default: first style found in profile

=item * C<vars> I<HashRef> - variables to be inserted into (i.e. required by) the template text, required

=back

=cut
command "render_subject_from_template" => {
    profile => { isa => 'AlphaPunct', required => 1, },
    style   => { isa => 'AlphaPunct', },
    vars    => { isa => 'HashRef',    required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $config = CTX('config');

    my $profile = $params->profile;
    my $vars    = $params->vars; $self->cleanup_for_tt($vars);
    my $style;
    if ($params->has_style) {
        $style = $params->style;
    }
    else {
        my @styles = $config->get_keys("profile.$profile.style");
        $style = (sort @styles)[0];
        ##! 8: 'Autodetected style ' . $style
    }

    my $dn_template = $config->get("profile.$profile.style.$style.subject.dn")
        or OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_PROFILE_RENDER_SUBJECT_FROM_TEMPLATE_NO_DN_TEMPLATE',
            params  => {
                PROFILE => $profile,
                STYLE   => $style,
            }
        );

    return $self->process_template($dn_template, $vars);
};

=head2 render_san_from_template

Renders a list of SANs by using the text template as defined in the
certificate profile (C<profile.XXX.style.XXX.subject.san>) and the given variables.

The result is formatted for use with the crypto backend and might be undef if
nothing is found.

If additional SANs are specified they are merged with the results of the template
parser, duplicates are removed. Expected hash format (empty refs are ok):

    { DNS => [ 'www.example.com', 'www.example.org' ] }

Configuration example:

  subject:
    san:
      dns:
      - "[% hostname %]"
      - "[% FOREACH entry = hostname2 %][% entry %]|[% END %]"
      email: [% email %]

B<Parameters>

=over

=item * C<profile> (Str) - certificate profile, required

=item * C<style> (Str) - profile substyle, default: first style found in profile

=item * C<vars> (HashRef) - variables to be inserted into (i.e. required by) the template text, required

=item * C<additional> (HashRef) - additional SANs, default: none

=back

=cut
command "render_san_from_template" => {
    profile    => { isa => 'AlphaPunct', required => 1, },
    style      => { isa => 'AlphaPunct', },
    vars       => { isa => 'HashRef',    required => 1, },
    additional => { isa => 'HashRef', },
} => sub {
    my ($self, $params) = @_;

    my $config = CTX('config');

    my $profile = $params->profile;
    my $vars    = $params->vars; $self->cleanup_for_tt($vars);
    my $items   = $params->has_additional ? $params->additional : {};
    my $style;
    if ($params->has_style) {
        $style = $params->style;
    }
    else {
        my @styles = $config->get_keys("profile.$profile.style");
        $style = (sort @styles)[0];
        ##! 8: 'Autodetected style ' . $style
    }

    my $profile_path = "profile.$profile.style.$style.subject";

    # Fix CamelCasing on preset items
    my $san_names = $self->api->list_supported_san();
    for my $key (keys %{$items}) {
        my $cckey = $san_names->{lc($key)};
        if ($key ne $cckey) {
            $items->{$cckey} = $items->{$key};
            delete $items->{$key};
        }
    }

    # Render SAN Template from input vars
    my @san_template_keys = $config->get_keys("$profile_path.san");
    for my $type (@san_template_keys) {
        my @entries;
        ##! 32: 'SAN Type ' . $type
        my @values = $config->get_scalar_as_list("$profile_path.san.$type");
        ##! 32: "Found SAN templates: " . Dumper @values;
        # Correct the Spelling of the san type
        my $cctype = $san_names->{lc($type)}
            or OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_PROFILE_RENDER_SAN_FROM_TEMPLATE_UNKNOWN_SAN_TYPE',
                params  => { SANKEY => $type, },
            );

        # Each list item is a template to be parsed
        for my $line_template (@values) {
            my $result = $self->process_template($line_template, $vars);
            ## split up internal multiples (sep by |)
            push @entries, (split (/\|/, $result)) if $result;
        }

        # merge into the preset hash
        $items->{$cctype} //= [];
        push @{$items->{$cctype}}, @entries;
    }

    my @san_list;
    for my $type (keys %{$items}) {
        # Remove duplicates
        my %entry;
        for my $key ( @{$items->{$type}} ) {
            next unless defined $key;
            $key =~ s{ \A \s+ }{}xms;
            $key =~ s{ \s+ \z }{}xms;
            next if $key eq '';
            $entry{$key} = 1;
        }

        # convert to the internal format used by our crypto engine
        for my $value (keys %entry) {
            push @san_list, [ $type, $value ] if $value;
        }
    }

    ##! 16: 'san list ' . Dumper @san_list
    return \@san_list;
};

=head2 render_metadata_from_template

Renders a HashRef metadata entries by using the text template as defined in the
certificate profile (C<profile.XXX.style.XXX.metadata>) and the given variables.

The return HashRef's values are either scalars (single metadata item) or
ArrayRefs (metadata lists, separated by pipe "|" in config). Empty template
parsing results are not stored.

Configuration example:

  metadata:
      requestor: "[% requestor_gname %] [% requestor_name %]"

B<Parameters>

=over

=item * C<profile> (Str) - certificate profile, required

=item * C<style> (Str) - profile substyle, default: first style found in profile

=item * C<vars> (HashRef) - variables to be inserted into (i.e. required by) the template text, required

=back

=cut
command "render_metadata_from_template" => {
    profile    => { isa => 'AlphaPunct', required => 1, },
    style      => { isa => 'AlphaPunct', },
    vars       => { isa => 'HashRef',    required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $config = CTX('config');

    my $profile = $params->profile;
    my $vars    = $params->vars; $self->cleanup_for_tt($vars);
    my $style;
    if ($params->has_style) {
        $style = $params->style;
    }
    else {
        my @styles = $config->get_keys("profile.$profile.style");
        $style = (sort @styles)[0];
        ##! 8: 'Autodetected style ' . $style
    }

    my $profile_path = "profile.$profile.style.$style.metadata";
    # Check for SAN Template
    my @meta_template_keys = $config->get_keys("$profile_path");
    my $metadata = {};

    return undef unless scalar @meta_template_keys;

    for my $type (@meta_template_keys) {
        my @entries;
        ##! 32: 'Meta Key ' . $type
        my @values = $config->get_scalar_as_list("$profile_path.$type");
        ##! 32: "Found Meta templates: " . Dumper @values;

        # Each list item is a template to be parsed
        for my $line_template (@values) {
            my $result = $self->process_template($line_template, $vars);
            ## split up internal multiples (sep by |)
            push @entries, (split (/\|/, $result)) if ($result);
        }

        ##! 32: 'Entries are ' . Dumper @entries

        # Remove duplicates and split up internal multiples (sep by |)
        my %items;
        for my $key (@entries) {
            $key =~ s{ \A \s+ }{}xms;
            $key =~ s{ \s+ \z }{}xms;
            next if ($key eq '');
            $items{$key} = 1;
        }

        my @items = keys %items;
        if (scalar @items == 1) {
            $metadata->{$type} = $items[0];
        }
        elsif (scalar @items > 1) {
            $metadata->{$type} = \@items;
        }

    }

    ##! 16: 'metadata' . Dumper $metadata
    return $metadata;

};

=head1 METHODS

=head2 process_template

Process the given text template via L<Template/process> using the given variables.

B<Parameters>

=over

=item * C<$template> (Str) - text template for TT

=item * C<$vars> (HashRef) - variables for TT

=back

=cut
sub process_template {
    my ($self, $template, $vars) = @_;
    my $result;

    my $oxtt = OpenXPKI::Template->new();
    my $res = $oxtt->render( $template, $vars );

    return $res;

}

=head2 cleanup_for_tt

Cleans up the given HashRef of variables for use in L<Template> Toolkit.

This modifies the argument HashRef!

B<Parameters>

=over

=item * C<$vars> (HashRef) - variables for TT

=back

=cut
sub cleanup_for_tt {
    my ($self, $vars) = @_;

    # TT has issues with empty values so we delete keys without content
    map {
        delete $vars->{$_} if ( ref $vars->{$_} eq '' && (!defined $vars->{$_} || $vars->{$_} eq '') );
        delete $vars->{$_} if ( ref $vars->{$_} eq 'HASH' && (!%{$vars->{$_}}) );
        delete $vars->{$_} if ( ref $vars->{$_} eq 'ARRAY' && (!@{$vars->{$_}} || !defined $vars->{$_}->[0] ) );
    } keys(%{$vars});

}

__PACKAGE__->meta->make_immutable;
