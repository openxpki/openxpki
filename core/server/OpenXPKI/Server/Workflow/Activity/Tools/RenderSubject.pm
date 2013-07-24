# OpenXPKI::Server::Workflow::Activity::Tools::RenderSubject
# Written by Oliver Welterfor the OpenXPKI Project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::RenderSubject;

use strict;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Context qw( CTX );
use English;
use Template;
use Data::Dumper;

use base qw( OpenXPKI::Server::Workflow::Activity );

sub execute {
    my $self     = shift;
    my $workflow = shift;
 
    ##! 8: 'Start'
        
    my $context = $workflow->context();    
    my $config = CTX('config');
        
    my $tt = new Template();
    my $ser = new OpenXPKI::Serialization::Simple;
    my $result;

    my %san_names = map { lc($_) => $_ } ('email','URI','DNS','RID','IP','dirName','otherName','GUID','UPN','RID');

    # Get the profile name and style
    my $profile = $context->param('cert_profile');
    my $style = $context->param('cert_subject_style');
    
    if (!$profile  || !$style) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_RENDER_SUBJECT_NO_PROFILE',
            params  => {
                PROFILE => $profile,
                STYLE   => $style,
            }
        );
    }
    
    # Load the dn and san template from the profile definition
    my $profile_path = "profile.$profile.style.$style.subject"; 
    my $dn_template = $config->get("$profile_path.dn");
    
    if (!$dn_template) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_RENDER_SUBJECT_NO_DN_TEMPLATE',
            params  => {
                PROFILE => $profile,
                STYLE   => $style,
            }
        );
    }    

    # Render the DN - get the input data from the context    
    my $template_vars = $ser->deserialize(  $context->param('cert_subject_parts') );
    my $subject_vars = {};    
    # Remove the "cert_subject" prefix
    foreach my $key (keys %{$template_vars}) {
        my ($template_key) = ($key =~ m{ \A cert_subject_(.*) \z }xms); 
        $subject_vars->{$template_key} = $template_vars->{$key};
        # Escape Comma 
        $subject_vars->{$template_key} =~ s{,}{\\,}xmsg;
    }   
    my $cert_subject;
    $tt->process(\$dn_template, $subject_vars, \$cert_subject);
    
    if (!$cert_subject) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_RENDER_SUBJECT_DN_RESULT_EMPTY',
            params  => {
                TEMPLATE => $dn_template
            }
        );
    }



    # Check for SAN Template    
    my @san_template_keys = $config->get_keys("$profile_path.san");
    
    my @san_list;    
    # If san template is defined we force template mode
    if (scalar @san_template_keys) {
        ##! 16: 'Template mode' 
        
        foreach my $type (@san_template_keys) {
            my @entries;
            ##! 32: 'SAN Type ' . $type            
            my @values = $config->get_scalar_as_list("$profile_path.san.$type");
            ##! 32: "Found SAN templates: " . Dumper @values;
            # Correct the Spelling of the san type
            $type = $san_names{lc($type)};
            # Each list item is a template to be parsed
            foreach my $line_template (@values) {  
                my $result; 
                $tt->process(\$line_template, $subject_vars, \$result);
                ##! 32: "Result of $line_template: $result\n";
                push @entries, $result if ($result);
            }
            
            # Remove duplicates and split up internal multiples (sep by |)
            my %items = map { my $key; $key =~ s/\s*(\S.*\S)\s*/$1/; $key => 1 } split("|", join ("|", @entries) );
            
            # convert to the internal format used by our crypto engine 
            foreach my $value (keys %items) {
                push @san_list, [ $type, $value ] if ($value);
            }
        }
        
    } elsif ( my $san_data = $context->param('cert_subject_alt_name_parts') ) {
        ##! 16: 'Freestyle mode'     
                       
        my $subject_alt_name_parts = $ser->deserialize( $context->param('cert_subject_alt_name_parts') );
        
        # remap to a structured hash $san_items->{type}->{value} = 1
        my $san_items = {};
        foreach my $key (grep m{ _key \z }xms, keys %{ $subject_alt_name_parts }) {
            my ($id) = ($key =~ m{ \A cert_subject_alt_name_(.*)_key \z }xms);
            if (! ref $subject_alt_name_parts->{$key}) {
                # scalar case
                my $type  = $subject_alt_name_parts->{$key};
                my $value = $subject_alt_name_parts->{
                            'cert_subject_alt_name_' . $id . '_value'};
                if ($type =~ m{ \A ((?: \d+\.)+ \d) \z}xms) { # type is an OID
                    my $oid  = $1;
                    $type = 'otherName';
                    $value = $oid . ';UTF8:' . $value;
                }
                $san_items->{$type}->{$value} = 1 if($value);
            }
            elsif (ref $subject_alt_name_parts->{$key} eq 'ARRAY') {
                for (my $i = 0; $i < scalar @{ $subject_alt_name_parts->{$key} }; $i++) {
                    my $type  = $subject_alt_name_parts->{$key}->[$i];
                    my $value = $subject_alt_name_parts->{
                            'cert_subject_alt_name_' . $id . '_value'}->[$i];
                    if ($type =~ m{ \A (\d+\.)+\d \z}xms) { # type is an OID
                        my $oid  = $1;
                        $type = 'otherName';
                        $value = $oid . ';UTF8:' . $value;
                    }
                    $san_items->{$type}->{$value} = 1 if($value);  
                }
            }
        }
       
        # Map the items hash to the internal san_array structure
        foreach my $type (keys %{$san_items}) {
            my $ctype = $san_names{lc($type)};
            # convert to the internal format used by our crypto engine 
            foreach my $value (keys %{$san_items->{$type}}) {
                push @san_list, [ $ctype, $value ] if ($value);
            }                    
        }
          
    } else {
        ##! 8: 'No SAN definition'
        
    }

    ##! 64: "Entries in san_list \n" .  Dumper @san_list;
    
    # store in context
    $context->param('cert_subject' => $cert_subject);
    
    $context->param('cert_subject_alt_name' => $ser->serialize( \@san_list ));


    return 1;
    
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::RenderSubject;

=head1 Description

Take the input parameters provided by the ui and render the subject and
subject alternative according to the profiles template definition.
There are two different parsing modes "template" and "freestyle", which
are autodetected by the presence of the "san" section in either the 
subject part (template) or the "ui" part (freestyle). 

=head2 Template Mode

In template mode, you MUST not define any SAN input field in the ui section.
You CAN specify a san section using the same values as in the subject field.

Example: 

  ui:
    subject:
    - hostname
    - hostname2
    - port
    
  subject: 
    dn: CN=[% hostname %][% IF port AND port != 443 %]:[% port %][% END %],DC=Test Deployment,DC=OpenXPKI,DC=org
    san: 
      dns: 
      - "[% hostname %]"
      - "[% FOREACH entry = hostname2 %][% entry %]|[% END %]"   

This will end up with a certificate which has the hostname as CN and 
additionally copied to the SAN. A second hostname is also put into the SAN
section, empty or duplicate values are purged, in case that hostname2
is an array (multi input field), you need to use a foreach loop and end
each entry with the pipe symbol |. Hint: The foreach loop automagically 
degrades if the given value is a scalar or even undef, so use foreach 
whenever a list is possible.       

=head2 Freestyle Mode

In freestyle mode, the subject dn is parsed the same way as in template mode.
If you specify input fields in the ui section of your profile, the user can 
enter his desired values for each san key. The users input is mapped without
further templating to the san section of the certificate (duplicate items and
and leading/trailing whitespace are removed). 

=head2 Parameters in context:

=over 

=item cert_subject_parts

The main subject parameters, used for rendering the subject dn and in template
mode for the san. The "cert_subject_" prefix is removed from the keys name.

=item cert_subject_alt_name_parts

Used in freestyle mode to form the san. 

=item cert_profile

Determines the used profile.

=item cert_subject_style

Determines the used profile substyle-

=item cert_subject

Holds the result for the subject. 

=item cert_subject_alt_name

Holds the result for the san section.

=back

