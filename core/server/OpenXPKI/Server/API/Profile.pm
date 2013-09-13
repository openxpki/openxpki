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
use Digest::SHA1 qw( sha1_base64 );
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
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_API_DEFAULT_NO_SUCH_INPUT_ELEMENT_DEFINED",
                params => {
                    'input' => $input_name,
                    'profile' => $profile,
                }
            );
        }

        # Uppercase the keys and push it to the array
        my %ucinput = map { uc $_ => $input->{$_} } keys %{$input};
        if (defined $csr_info) {

            my $source = $input->{'source'};
            ##! 16: 'source: ' . $source
            # if source is defined, use it with $csr_info ...
            if (defined $source) {
                my ($part, $regex) = ($source =~ m{([^:]+) : (.+)}xms);
                ##! 16: 'part: ' . $part
                ##! 16: 'regex: ' . $regex
                my $part_from_csr;
                eval {
                    # try to get data from csr info hash
                    # currently, we only get the first entry
                    # for the given part (so we can not deal
                    # with multiple OUs, for example)
                    $part_from_csr = $csr_info->{BODY}->{SUBJECT_HASH}->{$part}->[0];
                };
                ##! 16: 'part from csr: ' . $part_from_csr
                if (defined $part_from_csr) {
                    my ($match) = ($part_from_csr =~ m{$regex}xms);
                    ##! 16: 'match: ' . $match
                    # override default value with the result of the
                    # regex matching
                    $ucinput{DEFAULT} = $match;
                }
            }
        }
 
        # if type is select, add options array ref
        if ($ucinput{TYPE} eq 'select') {
            ##! 32: 'type is select'
            my @options = $config->get_list("$input_path.option");
            $ucinput{OPTIONS} = \@options;                  
        }
        
        # SAN use fields with dynamic key/value assignment 
        # We introduce a new type "dynamic" for that
        if ($ucinput{TYPE} eq 'keyvalue') {            
            # "key" and "value" are a hash            
            foreach my $key (qw(key value)) {
                my %hash = %{$config->get_hash("$input_path.$key")};
                %hash = map { uc $_ => $hash{$_} } keys %hash;                     
                # To make it worse, they can have options which is a list of hash
                if ($hash{TYPE} eq 'select') {
                    my @options;                    
                    for (my $i=0; $i<$config->get_size("$input_path.$key.option"); $i++) {
                       my %sub = %{$config->get_hash("$input_path.$key.option.$i")};
                       %sub = map { uc $_ => $sub{$_} } keys %sub;
                       push @options, \%sub;  
                    }                    
                    $hash{OPTIONS} = \@options; 
                }                
                $ucinput{uc($key)} = \%hash;
            }
        }
        push @definitions, \%ucinput; 
    }
    ##! 64: 'Definitions: ' . Dumper @definitions
    return \@definitions;    
}


sub get_cert_subject_styles {
    my $self      = shift;
    my $arg_ref   = shift;
    my $profile   = $arg_ref->{PROFILE};
    my $cfg_id    = $arg_ref->{CONFIG_ID};
    my $pkcs10    = $arg_ref->{PKCS10};
    ##! 1: 'start'

    my $config = CTX('config');
    
    my $csr_info;
    if (defined $pkcs10) {
        # if PKCS#10 data is passed, we need to get the info from
        # the data ...
        ##! 16: 'pkcs10 defined'
        $csr_info = CTX('api')->get_csr_info_hash_from_data({
            DATA => $pkcs10,
        });
        ##! 64: 'csr info: ' . Dumper $csr_info
    }

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
                $self->__fetch_input_element_definitions( $profile, \@input_names, $csr_info);            
            
        
        # Do the same for the additional info parts
        @input_names = $style_config->get_list('ui.info');        

        $styles->{$id}->{ADDITIONAL_INFORMATION}->{INPUT} = 
            $self->__fetch_input_element_definitions( $profile, \@input_names, $csr_info );            
        
        # And again for SANs
        @input_names = $style_config->get_list('ui.san');        
        
        $styles->{$id}->{SUBJECT_ALTERNATIVE_NAMES} = 
            $self->__fetch_input_element_definitions( $profile, \@input_names ); # no csr_info for san            
        
    }
    ##! 128: 'styles: ' . Dumper $styles
    return $styles;
}

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

sub get_possible_profiles_for_role {
    my $self      = shift;
    my $arg_ref   = shift;
    my $req_role  = $arg_ref->{ROLE};
     
    ##! 1: 'start'
    ##! 16: 'Requested role ' . $req_role

    my $config = CTX('config');    
    my @profiles = $config->get_keys('profile');
    my @matching_profiles; 
    
    foreach my $profile (@profiles) {
        my @roles = $config->get_list("profile.$profile.role");
        ##! 16: "Profile $profile, Roles " .join " ", @roles              
        if (grep /^$req_role$/,  @roles) {
            ##! 16: 'Profile matches role' 
            push @matching_profiles, $profile;     
        }
    }
    
    ##! 1: 'end'
    return \@matching_profiles;
}
  

sub get_available_cert_roles {
    my $self      = shift;
    my $arg_ref   = shift;

    my %available_roles = ();

    ##! 1: 'start'
    my $config = CTX('config');
    my @profiles; 
    if ($arg_ref->{PROFILES}) {
        @profiles = @{$arg_ref->{PROFILES}};
    } else {
        @profiles = $config->get_keys('profile');    
    }
    
    ##! 16: 'Profiles ' .join " ", @profiles     
    foreach my $profile (@profiles) {
        my @roles = $config->get_list("profile.$profile.role");
        ##! 16: 'Roles ' .join " ", @roles
        map { $available_roles{$_} = 1 if ($_); } @roles;
    }
 
    ##! 1: 'end'    
    my @roles = keys %available_roles;
    return \@roles;
}

sub get_cert_profiles {
    
    my $config = CTX('config');    

    my %profiles = map { $_ => 1 } $config->get_keys('profile');
    
    delete $profiles{'template'};

    ##! 16: 'Profiles ' .Dumper %profiles
    
    return \%profiles;
}
 
sub get_cert_subject_profiles {
    my $self = shift;
    my $args = shift;
    my $profile = $args->{PROFILE};

    ##! 1: 'Start '

    my $config = CTX('config');    

    my @style_names = $config->get_keys("profile.$profile.style");

    ## get all available profiles
    my %styles = ();
    foreach my $style (@style_names) {        
        $styles{$style}->{LABEL}       = $config->get("profile.$profile.style.$style.label");
        $styles{$style}->{DESCRIPTION} = $config->get("profile.$profile.style.$style.description");
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

    my $cert_subject;
    my $tt = Template->new();
    $tt->process(\$dn_template, $vars, \$cert_subject);
    
    return $cert_subject;
       
}

sub render_san_from_template {
    
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
        
    my $profile_path = "profile.$profile.style.$style.subject";        
    # Check for SAN Template    
    my @san_template_keys = $config->get_keys("$profile_path.san");    
    my @san_list; 
    
    if (! scalar @san_template_keys) { return undef; }
    
    my $tt = Template->new();
    
    # Fix CamelCaseing
    my $san_names = $self->list_supported_san();    
    
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
            $tt->process(\$line_template, $vars, \$result);
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

        # convert to the internal format used by our crypto engine 
        foreach my $value (keys %items) {                        
            push @san_list, [ $cctype, $value ] if ($value);
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
            $tt->process(\$line_template, $vars, \$result);
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


=head2 get_available_cert_roles

Parameters:

  PROFILES  arrayref of profiles to query

Scan through profiles and find all roles inside them.
If PROFILES is given, scan only through those profiles. 
Return the role names as arrarref. 

=head2 get_cert_profiles

Return a hash ref with all profiles. The key is the id of the profile, the 
value was formerly set as the position in the xml tree, not it is simply "1".


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
    
