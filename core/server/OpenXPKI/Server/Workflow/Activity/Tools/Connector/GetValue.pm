# OpenXPKI::Server::Workflow::Activity::Tools::Connector::GetValue
# Written by Oliver Welter for the OpenXPKI project 2012
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Connector::GetValue;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Template;
use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    
    my $connector_key;
                  
    # Use value in ds_key_param as key in Connector
    my $keyparam = $self->param('ds_key_param');
    
    if ($keyparam) {
        $connector_key = $context->param( $keyparam );
    }
    
    my $keytemplate = $self->param('ds_key_template');    
    # Template based key 
    if ( not $connector_key && defined $keytemplate ) {

        ##! 32: ' Use TT Template ' . $keytemplate
                
        # Get Issuer Info from selected ca 
        my %template_vars = (
            PKI_REALM => CTX('api')->get_pki_realm(),
            CONTEXT => {}  
        ); 
        
        # find all CONTEXT.* occurences in template and load them into template vars
        # $template = ' [- CONTEXT.SUBJECT -].[- CONTEXT.token_id -] ';
        my @keys = ($keytemplate =~ /\[- CONTEXT.([^\]]+) -\]/g);
        
        foreach my $key (@keys) {
            ##! 32: ' Add key to template ' . $key
            $template_vars{CONTEXT}->{$key} = $context->param( $key );
        }   
        
        ##! 32: ' Template Vars ' . Dumper ( %template_vars )  
        
        #$keytemplate = '[% TAGS [- -] -%]' .  $keytemplate;
        my $tt = Template->new();        
        $tt->process(\$keytemplate, \%template_vars, \$connector_key);                    

        if ( not defined $connector_key ) {
            OpenXPKI::Exception->throw( message =>
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_CONNECTOR_TEMPLATE_FAILED'
            )
        }        
    }
    
    if ( not $connector_key ) {
        OpenXPKI::Exception->throw( message =>
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_CONNECTOR_MISSPARAM_KEY_PARAM'
        )
    }
    
    my $valparam = $self->param('ds_value_param');
    if ( not defined $valparam ) {
        OpenXPKI::Exception->throw( message =>
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_CONNECTOR_MISSPARAM_VALUE_PARAM'
        )
    }
    
    
    my $retval;
    # Array Mode
    if ($self->param('ds_wantarray')) {
    
        ##! : 16 'Array mode'
        my @retarray = CTX('config')->get_list( $connector_key );
        my $ser = OpenXPKI::Serialization::Simple->new();
        $retval = $ser->serialize( \@retarray );
               
    } else {
        $retval = CTX('config')->get( $connector_key );
    }
    
    # undef - fall back to default if configured
    if ( not defined $retval ) {
        my $default_value = $self->param('ds_default_value');        
        if ( defined $default_value ) {
            if ( $default_value =~ s/^\$// ) {
                $retval = $context->param($default_value);
            } else {
                $retval = $default_value;
            }                         
        } 
    }

    ##! 1: 'Ask for '.$connector_key.' and got '. Dumper ( $retval )
    $context->param($valparam, $retval);

    return 1;    
            
}
 
1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Connector::GetEntry

=head1 Description

This activity reads a value from the config connector into the context. 

=head1 Configuration

=head2 Parameters

In the activity definition, the following parameters must be set.
See the example that follows.

=over 8

=item ds_key_param

The name of the context parameter that contains the key for the connector
lookup operation.

=item ds_key_template

A template toolkit pattern to create the the key for the connector lookup 
from. You can refer to every value in the context with C<CONTEXT.<param name>>
and the name of the current realm with C<PK_REALM>.
This is effective only if ds_key_param or the named context value is not set.

=item ds_value_param

The name of the context parameter to which the determined value should be 
written.

=item ds_default_value

The default value to be returned if the connector did not return a result. 
If preceeded with a dollar symbol '$', then the workflow context variable 
with the given name will be used. This is optional.

=item ds_wantarray

If you are asking the config tree for a node which returns a list of scalars,
you need to set this to a true value.  

=back

=head2 Arguments

The workflow action requires two parameters that are passed via the
workflow context. The names are set above with the I<ds_key_param> and
I<ds_value_param> parameters. Instead of I<ds_key_param> you can also 
set I<ds_key_template>. All other parameters are optional.

=head2 Return Value

The resulting value is written to the workflow context at the specified key.

=head2 Example

  <action name="set_context_from_config"
    class="OpenXPKI::Server::Workflow::Activity::Tools::Connector::GetEntry"        
    ds_key_param="query"
 	ds_key_template="smartcard.puk.default.[- CONTEXT.token_id -]"
    ds_value_param="puk"
    ds_wantarray="0"> 	
    
    <field name="token_id" label="Serial number of Smartcard"/>
  </action>

