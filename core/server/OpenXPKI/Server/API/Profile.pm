## OpenXPKI::Server::API::Profile.pm
##
## Written 2013 by Oliver Welter for the OpenXPKI project
## Copyright (C) 2005-2013 by The OpenXPKI Project
package OpenXPKI::Server::API::Profile;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

use Data::Dumper;

#use Regexp::Common;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::i18n qw( set_language );
use Digest::SHA qw( sha1_base64 );
use DateTime;

use Template;

use Workflow;

sub START {
    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED',
    );
}
# API: simple retrieval functions


sub __fetch_input_element_definitions {

    my $self = shift;
    my $profile = shift;
    my $input_names = shift;
    my $csr_info = shift;

    if ($csr_info) {
        OpenXPKI::Exception->throw(
            message => 'input rendering with pkcs10 is deprecated',
        );
    }

    my $config = CTX('config');

    my @definitions;

    foreach my $input_name (@{$input_names}) {
        my ($input, $input_path);
        ##! 32: "Input $input_name"
        # each input name can have a local or/and a global definiton,
        # we need to probe where to find it
        foreach my $path ("profile.$profile.template.$input_name", "profile.template.$input_name") {
            $input = $config->get_hash($path);
            if ($input) {
                ##! 64: "Element found at $path"
                $input_path = $path;
                last;
            }
        }

        if (!$input) {
            # check if there is a default section (only look in the profile!)
            $input = $config->get_hash(['profile', $profile, 'template' , '_default' ]);
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_API_DEFAULT_NO_SUCH_INPUT_ELEMENT_DEFINED",
                params => {
                    'input' => $input_name,
                    'profile' => $profile,
                }
            ) unless($input);

            # got a default item, create field using default
            # set id and label to name
            $input->{id} = $input_name;
            $input->{label} = $input_name;

        }

        # Uppercase the keys and push it to the array
        my %ucinput = map { uc $_ => $input->{$_} } keys %{$input};

        # if type is select, add options array ref
        if ($ucinput{TYPE} eq 'select') {
            ##! 32: 'type is select'
            my @options = $config->get_list("$input_path.option");
            $ucinput{OPTIONS} = \@options;
        }

        # SAN use fields with dynamic key/value assignment
        # Those have a special section "keys" which is a list of hashes
        # Get size of list to iterate
        if ($ucinput{KEYS}) {
            my $size = $config->get_size("$input_path.keys");
            my @keys;
            for (my $i=0;$i<$size;$i++) {
                my $key = $config->get_hash( "$input_path.keys.$i" );
                push @keys, { value => $key->{value}, label => $key->{label} };
            }
            $ucinput{KEYS} = \@keys;
        }

        if ($ucinput{MIN} || $ucinput{MAX}) {
            $ucinput{CLONABLE} = 1;
        }


#=begin disabled-by-oli
#
#        if ($ucinput{TYPE} eq 'keyvalue') {
#            # "key" and "value" are a hash
#            foreach my $key (qw(key value)) {
#                my %hash = %{$config->get_hash("$input_path.$key")};
#                %hash = map { uc $_ => $hash{$_} } keys %hash;
#                # To make it worse, they can have options which is a list of hash
#                if ($hash{TYPE} eq 'select') {
#                    my @options;
#                    for (my $i=0; $i<$config->get_size("$input_path.$key.option"); $i++) {
#                       my %sub = %{$config->get_hash("$input_path.$key.option.$i")};
#                       %sub = map { uc $_ => $sub{$_} } keys %sub;
#                       push @options, \%sub;
#                    }
#                    $hash{OPTIONS} = \@options;
#                }
#                $ucinput{uc($key)} = \%hash;
#            }
#        }
#
#=end disabled-by-oli

        push @definitions, \%ucinput;
    }
    ##! 64: 'Definitions: ' . Dumper @definitions
    return \@definitions;
}


sub get_cert_subject_styles {
    my $self      = shift;
    my $arg_ref   = shift;
    my $profile   = $arg_ref->{PROFILE};

    ##! 1: 'start'

    my $config = CTX('config');

    my $styles = {};

    my @style_names = $config->get_keys("profile.$profile.style");

    ##! 16: 'styles: ' . Dumper @style_names
    # iterate over all subject styles
    foreach my $id (@style_names) {

        ##! 64: 'style id: ' . $id
        my $style_config = $config->get_wrapper("profile.$profile.style.$id");

        # verbose texts
        foreach my $key (qw(label description)) {
            ##! 32: "Key: $key, Value: " . $style_config->get($key)
            $styles->{$id}->{uc($key)} = $style_config->get($key);
        }

        # subject + san toolkit template
        $styles->{$id}->{DN} = $style_config->get('subject.dn');

        # The names of the fields are a list at ui.subject
        my @input_names = $style_config->get_list('ui.subject');

        # The helper probes for the field definitions
        # and loads them into a suitable hash structure
        $styles->{$id}->{TEMPLATE}->{INPUT} =
                $self->__fetch_input_element_definitions( $profile, \@input_names);


        # Do the same for the additional info parts
        @input_names = $style_config->get_list('ui.info');

        $styles->{$id}->{ADDITIONAL_INFORMATION}->{INPUT} =
            $self->__fetch_input_element_definitions( $profile, \@input_names );

        # And again for SANs
        @input_names = $style_config->get_list('ui.san');

        $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES} =
            $self->__fetch_input_element_definitions( $profile, \@input_names ); # no csr_info for san

    }
    ##! 128: 'styles: ' . Dumper $styles
    return $styles;
}

# For ALL profiles (for search mask)
sub get_additional_information_fields {
    my $self      = shift;
    my $arg_ref   = shift;

    ##! 1: 'start'
    my $config = CTX('config');
    my @profiles = $config->get_keys('profile');

    ##! 32: 'Found profiles : ' . Dumper @profiles

    my $additional_information = {};

    # iterate through all profile and summarize all additional information
    # fields (may be redundant and even contradicting, but we only collect
    # the 'union' of these here; first one wins...)
    foreach my $profile (@profiles) {
        ##! 16: 'profile  ' . $profile
        my @fields;
        foreach my $style ($config->get_keys("profile.$profile.style")) {
            push @fields, $config->get_list("profile.$profile.style.$style.ui.info");
        }

        ##! 32: 'Found fields: ' . join ", ", @fields

        foreach my $field (@fields) {

            # We need only one hit per field
            next if $additional_information->{ALL}->{$field};

            # Resolve labels for fields
            foreach my $path ("profile.$profile.template.$field", "profile.template.$field") {
                if (my $label = $config->get("$path.label")) {
                    ##! 16: "additional information: $field (label: $label)"
                    $additional_information->{ALL}->{$field} = $label;
                    last;
                }
            }
        }
    }
    return $additional_information;
}

# new ui - get definition hashes for requested fields
sub get_field_definition {
    my $self      = shift;
    my $arg_ref   = shift;
    ##! 1: 'start'

    my $fields = $arg_ref->{FIELDS};
    # If STYLE is given we lookup the fields from the profile ourself
    if (!$fields && $arg_ref->{STYLE}) {
        my $section = $arg_ref->{SECTION} || 'subject';
        my @fields = CTX('config')->get_list(['profile', $arg_ref->{PROFILE}, 'style', $arg_ref->{STYLE}, 'ui', $section ]);
        ##! 16: 'fields ' . Dumper \@fields
        $fields = \@fields;
    }

    my $result = $self->__fetch_input_element_definitions($arg_ref->{PROFILE}, $fields);
    ##! 16: 'result ' . Dumper $result
    return $result;

}


sub get_cert_profiles {

    my $self = shift;
    my $args = shift;

    my $config = CTX('config');

    my $profiles;
    my @profile_names = $config->get_keys('profile');
    PROFILE:
    foreach my $profile (@profile_names) {
        next PROFILE if ($profile =~ /(template|default|sample)/);

        my $label = $config->get(['profile', $profile, 'label' ]) || $profile;
        if (!$args->{NOHIDE}) {
            ##! 32: "Evaluate UI for $profile"
            my @style_names = $config->get_keys(['profile', $profile, 'style' ]);
            foreach my $style (@style_names) {
                if ($config->exists(['profile', $profile, 'style', $style, 'ui' ])) {
                    ##! 32: 'Found ui style ' . $style
                    $profiles->{$profile} = { label => $label, value => $profile };
                    next PROFILE;
                }
            }
            ##! 32: 'No ui styles found'
        } else {
            $profiles->{$profile} = { value => $profile, label => $label };
        }
    }

    ##! 16: 'Profiles ' .Dumper $profiles

    return $profiles;
}

=head2

List profiles that are used for entity certificates in the current realm

=cut

sub list_used_profiles {
    my ($self, $args) = @_;
    my $pki_realm = $args->{PKI_REALM} ? $args->{PKI_REALM} : CTX('session')->data->pki_realm;

    my $profiles = CTX('dbi')->select(
        from => 'csr',
        columns => [ -distinct => 'profile' ],
        where => { pki_realm => $pki_realm },
    )->fetchall_arrayref({});

    return [
        map {
            {
                value => $_->{profile},
                label => CTX('config')->get(['profile', $_->{profile}, 'label']) || $_->{profile},
            }
        } @$profiles
    ];
}


sub get_cert_subject_profiles {
    my $self = shift;
    my $args = shift;
    my $profile = $args->{PROFILE};
    my $nohide = $args->{NOHIDE};

    ##! 1: 'Start '

    my $config = CTX('config');

    my @style_names = $config->get_keys("profile.$profile.style");

    ## get all available profiles
    my %styles = ();
    foreach my $style (@style_names) {

        # Hide No UI styles if NOHIDE is not set
        if (!($nohide || $config->exists(['profile', $profile, 'style', $style, 'ui' ]))) {
            next;
        }
        $styles{$style}->{LABEL}       = $config->get(['profile', $profile, 'style', $style, 'label']);
        $styles{$style}->{DESCRIPTION} = $config->get(['profile', $profile, 'style', $style, 'description']);
    }

    ##! 32: Dumper %profiles
    return \%styles;
}


sub render_subject_from_template {

    my $self = shift;
    my $args = shift;

    ##! 1: 'Start '

    my $profile = $args->{PROFILE};
    my $style = $args->{STYLE};
    my $vars = $args->{VARS};

    my $config = CTX('config');

    if (!$style) {
        my @styles = $config->get_keys("profile.$profile.style");
        @styles = sort @styles;
        $style = shift @styles;
        ##! 8: 'Autodetecting style ' . $style

    }

    my $dn_template = $config->get("profile.$profile.style.$style.subject.dn");
    if (!$dn_template) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_PROFILE_RENDER_SUBJECT_FROM_TEMPLATE_NO_DN_TEMPLATE',
            params  => {
                PROFILE => $profile,
                STYLE   => $style,
            }
        );
    }

    $self->__clean_vars( $vars );

    my $cert_subject;
    my $tt = Template->new();
    if (!$tt->process(\$dn_template, $vars, \$cert_subject)) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_PROFILE_RENDER_SUBJECT_FROM_TEMPLATE_ERROR_PARSING_TEMPLATE',
            params => {
                'TEMPLATE' => $dn_template,
                'ERROR' => $tt->error()
            }
        );
    }

    return $cert_subject;

}

sub render_san_from_template {

    my $self = shift;
    my $args = shift;

    ##! 1: 'Start '

    my $profile = $args->{PROFILE};
    my $style   = $args->{STYLE};
    my $vars    = $args->{VARS};
    my $items   = $args->{ADDITIONAL} || {};

    $self->__clean_vars( $vars );

    my $config = CTX('config');

    if (!$style) {
        my @styles = $config->get_keys("profile.$profile.style");
        @styles = sort @styles;
        $style = shift @styles;
        ##! 8: 'Autodetecting style ' . $style
    }

    my $profile_path = "profile.$profile.style.$style.subject";
    # Check for SAN Template
    my @san_template_keys = $config->get_keys("$profile_path.san");
    my @san_list;

    if (! scalar @san_template_keys) { return undef; }

    my $tt = Template->new();

    # Fix CamelCaseing
    my $san_names = $self->list_supported_san();

    # Fix CamelCasing on items
    foreach my $key (keys %{$items}) {
        my $cckey = $san_names->{lc($key)};
        if ($key ne $cckey) {
            $items->{$cckey} = $items->{$key};
            delete $items->{$key};
        }
    }

    foreach my $type (@san_template_keys) {
        my @entries;
        ##! 32: 'SAN Type ' . $type
        my @values = $config->get_scalar_as_list("$profile_path.san.$type");
        ##! 32: "Found SAN templates: " . Dumper @values;
        # Correct the Spelling of the san type
        my $cctype = $san_names->{lc($type)};
        if (!$cctype) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_PROFILE_RENDER_SAN_FROM_TEMPLATE_UNKNOWN_SAN_TYPE',
                params  => {
                    SANKEY => $type,
                }
            );
        }

        # Each list item is a template to be parsed
        foreach my $line_template (@values) {
            my $result;
            if (!$tt->process(\$line_template, $vars, \$result)) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_PROFILE_RENDER_SAN_FROM_TEMPLATE_ERROR_PARSING_TEMPLATE',
                    params => {
                        'TEMPLATE' => $line_template,
                        'ERROR' => $tt->error()
                    }
                );
            }
            ##! 32: "Result of $line_template: $result\n";

            ## split up internal multiples (sep by |)
            push @entries, (split (/\|/, $result)) if ($result);
        }

        # merge into the preset hash
        if ($items->{$cctype}) {
            push @{$items->{$cctype}}, @entries;
        } else {
            $items->{$cctype} = \@entries;
        }
    }

    foreach my $type (keys %{$items}) {

        ##! 32: 'Entries are ' . Dumper $items

        # Remove duplicates
        my %entry;
        foreach my $key ( @{$items->{$type}} ) {
            next if (!defined $key);
            $key =~ s{ \A \s+ }{}xms;
            $key =~ s{ \s+ \z }{}xms;
            next if ($key eq '');
            $entry{$key} = 1;
        }

        # convert to the internal format used by our crypto engine
        foreach my $value (keys %entry) {
            push @san_list, [ $type, $value ] if ($value);
        }
    }

    ##! 16: 'san list ' . Dumper @san_list
    return \@san_list;
}

sub render_metadata_from_template {

    my $self = shift;
    my $args = shift;

    ##! 1: 'Start '

    my $profile = $args->{PROFILE};
    my $style = $args->{STYLE};
    my $vars = $args->{VARS};

    $self->__clean_vars( $vars );

    my $config = CTX('config');

    if (!$style) {
        my @styles = $config->get_keys("profile.$profile.style");
        @styles = sort @styles;
        $style = shift @styles;
        ##! 8: 'Autodetecting style ' . $style
    }

    my $profile_path = "profile.$profile.style.$style.metadata";
    # Check for SAN Template
    my @meta_template_keys = $config->get_keys("$profile_path");
    my $metadata = {};

    if (! scalar @meta_template_keys) { return undef; }

    my $tt = Template->new();

    foreach my $type (@meta_template_keys) {
        my @entries;
        ##! 32: 'Meta Key ' . $type
        my @values = $config->get_scalar_as_list("$profile_path.$type");
        ##! 32: "Found Meta templates: " . Dumper @values;

        # Each list item is a template to be parsed
        foreach my $line_template (@values) {
            my $result;
            if (!$tt->process(\$line_template, $vars, \$result)) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_PROFILE_RENDER_METADATA_FROM_TEMPLATE_ERROR_PARSING_TEMPLATE',
                    params => {
                        'TEMPLATE' => $line_template,
                    }
                );
            }
            ##! 32: "Result of $line_template: $result\n";

            ## split up internal multiples (sep by |)
            push @entries, (split (/\|/, $result)) if ($result);
        }

        ##! 32: 'Entries are ' . Dumper @entries

        # Remove duplicates and split up internal multiples (sep by |)
        my %items;
        foreach my $key (@entries) {
            $key =~ s{ \A \s+ }{}xms;
            $key =~ s{ \s+ \z }{}xms;
            next if ($key eq '');
            $items{$key} = 1;
        }

        my @items = keys %items;
        if (scalar @items == 1) {
            $metadata->{$type} = $items[0];
        } elsif (scalar @items > 1) {
            $metadata->{$type} = \@items;
        }

    }

    ##! 16: 'metadata' . Dumper $metadata
    return $metadata;
}

sub list_supported_san {
    my %san_names = map { lc($_) => $_ } ('email','URI','DNS','RID','IP','dirName','otherName','GUID','UPN','RID');
    ##! 16: 'Supported san names ' . Dumper %san_names
    return \%san_names;
}

=head2 get_key_algs ( { PROFILE, NOHIDE } )

Return a list of supported key algorithms for the given profile.
Items starting with an underscore are hidden unless NOHIDE is true.

=cut

sub get_key_algs {


    my $self = shift;
    my $args = shift;

    my $profile = $args->{PROFILE};
    my $nohide = $args->{NOHIDE};

    my $config = CTX('config');

    if (!$config->exists( [ 'profile', $profile, 'key', 'alg' ] ) ) {
        $profile = 'default';
    }

    my @alg = $config->get_list( [ 'profile', $profile, 'key', 'alg' ] );

    # Filter argument starting with underscore
    if (!$nohide) {
        @alg = grep { $_ !~ /^_/ } @alg;
    } else {
        map { $_ =~ s/\A_// } @alg;
    }

    return \@alg;

}

=head2 get_key_enc ( { PROFILE, NOHIDE } )

Return a list of supported encryption algorithms for the given profile
Items starting with an underscore are hidden unless NOHIDE is true.

=cut

sub get_key_enc {

    my $self = shift;
    my $args = shift;

    my $profile = $args->{PROFILE};
    my $nohide = $args->{NOHIDE};


    my $config = CTX('config');

    if (!$config->exists( [ 'profile', $profile, 'key', 'enc' ] ) ) {
        $profile = 'default';
    }

    my @enc = $config->get_list( [ 'profile', $profile, 'key', 'enc' ] );

    # Filter argument starting with underscore
    if (!$nohide) {
        @enc = grep { $_ !~ /^_/ } @enc;
    } else {
        map { $_ =~ s/\A_// } @enc;
    }

    return \@enc;

}

=head2 get_key_params ( { PROFILE, ALG, NOHIDE } )

Returns all input parameters accepted by the selected algorithm
as defined for the given profile (or the default).
If no algorithm is given, only returns a list of all possible paramaters
in all algorithms (used for prerendering the UI forms)
Note: This does not check if the algorithm is in the supported list for
the given profile, use get_key_alg to check!

=cut

sub get_key_params {

    my $self = shift;
    my $args = shift;

    ##! 1: 'Start '

    my $profile = $args->{PROFILE};
    my $algorithm = $args->{ALG};
    my $nohide = $args->{NOHIDE};

    my $config = CTX('config');

    if (!$algorithm) {
        # TODO - grab that from the config
        return [ 'key_length', 'curve_name' ];
    }

    my $path;
    if (!$config->exists( [ 'profile', $profile, 'key', $algorithm ] ) ) {
        $profile = 'default';
    }

    my @keys = $config->get_keys( [ 'profile', $profile, 'key', $algorithm ] );
    my $params;
    foreach my $key (@keys) {
        my @param = $config->get_list( [ 'profile', $profile, 'key', $algorithm, $key ] );
        if (!$nohide) {
            @param = grep { $_ !~ /^_/ } @param;
        } else {
            map { $_ =~ s/\A_// } @param;
        }
        $params->{$key} = \@param if (@param);
    }

    return $params;

}

sub __clean_vars {

    my $self = shift;
    my $vars = shift;

    # TT has issues with empty values so we delete keys without content
    map {
        delete $vars->{$_} if ( ref $vars->{$_} eq '' && (!defined $vars->{$_} || $vars->{$_} eq '') );
        delete $vars->{$_} if ( ref $vars->{$_} eq 'HASH' && (!%{$vars->{$_}}) );
        delete $vars->{$_} if ( ref $vars->{$_} eq 'ARRAY' && (!@{$vars->{$_}} || !defined $vars->{$_}->[0] ) );
    } keys(%{$vars});

}

1;

__END__

=head1 NAME

OpenXPKI::Server::API::Profile

=head1 Description

This module contains the API functions related to handling profile information,
mainly parsing information for UI and DN rendering

=head1 Functions

=head2 get_possible_profiles_for_role

Returns an array reference of possible certificate profiles for a given
certificate role (passed in the named parameter ROLE) taken from the
configuration.

Parameters:

    NOHIDE: If set, show also Non-UI Profiles


=head2 get_cert_subject_styles

Returns the configured subject styles for the specified profile.

Parameters:

  PROFILE     name of the profile to query
  PKCS10      certificate request to parse (optional)

Returns a hash ref with the following structure:
FIXME

=head2 get_additional_information_fields

Returns a hash ref containing all additional information fields that are
configured.

Return structure: hash ref; key is the name of the field, value is the
corresponding I18N tag.

=head2 get_field_definition

Get the definition of input fields for a given profile/style.


=head2 get_available_cert_roles

Parameters:

  PROFILES  arrayref of profiles to query

Scan through profiles and find all roles inside them.
If PROFILES is given, scan only through those profiles.
Return the role names as arrarref.

=head2 get_cert_profiles

Return a hash ref with all UI profiles. The key is the id of the profile, the
value was formerly set as the position in the xml tree, not it is a hash with
additional data (for the moment only a label).

Parameters:

    NOHIDE: If set, show also Non-UI Profiles

=head2 get_cert_subject_profiles

Returns a hash with label and description of all subject styles for a
given profile. FIXME: The name is misleading.

=head2 render_subject_from_template

Loads the toolkit template string from the profile definition and
returns the result of the template parsing as string using vars as
input values. The style argument is optional and defautls to the
first style element in the profile. The result might be empty.

Parameters:

    PROFILE: name of the profile
    STYLE:   name of the substyle, if omited the first one is chosen
    VARS:    the vars to pass to the template parser


=head2 render_san_from_template

Loads the toolkit template from the profile definition and
returns the result of the template parsing using vars as
input values. The style argument is optional and defautls to the
first style element in the profile. The result is formatted for
use with the crypto backend and might be undef if nothing is found.

Parameters:

    PROFILE: name of the profile
    STYLE:   name of the substyle, if omited the first one is chosen
    VARS:    the vars to pass to the template parser
    ADDITIONAL: additional san as hash

The additional sans are merged with the results of the template parser,
duplicates are removed. Expected hash format (empty refs are ok):

    { DNS => [ 'www.example.com', 'www.example.org' ] }

Configuration example:

  subject:
    san:
      dns:
      - "[% hostname %]"
      - "[% FOREACH entry = hostname2 %][% entry %]|[% END %]"
      email: [% email %]


=head2 list_supported_san

return a hashref of all supported san attributes, the keys are all lowercase while
the value is in correct CamelCaseing for OpenSSL.

=head2 render_metadata_from_template

Uses the same syntax as render_san_from_template but uses the templates found
at style.<style>.metadata and returns a hashref.
Templates resulting in a single item are stores as scalar, empty results are
not stored, lists are inserted as array ref.

Configuration example:

  metadata:
      requestor: "[% requestor_gname %] [% requestor_name %]"

