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
    
    # Get prefix from vars - always asumed to be a string
    my $connector_prefix = $self->param('ds_key_prefix');
    
    # Usually we have only one key but in case we need more there is a syntax for it
    my $keynames = $self->param('ds_keylist') || 'ds_key';
    
    ##! 16: 'Keynames are ' . $keynames    
    my @keys = split /,/, $keynames;
    
    my @path;
    foreach my $key (@keys) {
        my $val = $self->param($key);
        next unless (defined $val && $val ne '');
        push @path, $val;
    }

    if ( not scalar @path ) {
        OpenXPKI::Exception->throw( message =>
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_CONNECTOR_GET_VALUE_NO_PATH'
        )               
    }
    
    ##! 16: 'Path is ' . Dumper @path
     
    ##! 64: 'Action params ' . Dumper $self->param() 
    my $valparam = $self->param('ds_value_param');
    my $valmap = $self->param('ds_value_map');           
    ##! 32: 'Param ' . $valparam
    ##! 32: 'Map ' . $valmap
    if ( not ( $valparam || $valmap ) ) {
        OpenXPKI::Exception->throw( message =>
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_CONNECTOR_MISSPARAM_VALUE_PARAM_OR_MAP'
        )
    }
        
    my $retval;

    # Am I evil? - hack to have a string prefix but use key array 
    my $wrapper = $connector_prefix ? 
        CTX('config')->get_wrapper( $connector_prefix ) : 
        CTX('config');
        

    # Hash Mode 
    if ($valmap) {
        my %attrmap = map { split(/\s*[=-]>\s*/) }
            split( /\s*,\s*/, $valmap );
            
        ##! : 16 'hash mode'
        ##! : 32 'attr map ' . Dumper %attrmap        
        my $hash = $wrapper->get_hash( \@path );
        
        foreach my $key (keys %attrmap) {
        	##! 32: 'Add item key: ' . $key .' - Value: ' . $attrmap{$key};
        	$context->param( $key, $hash->{$attrmap{$key}});
        }
        
    } else {
        # Array Mode
	    if ($self->param('ds_wantarray')) {
	    
	        ##! : 16 'Array mode'
	        my @retarray = $wrapper->get_list( \@path );;
	        my $ser = OpenXPKI::Serialization::Simple->new();
	        $retval = $ser->serialize( \@retarray );
	               
	    } else {
	        $retval = $wrapper->get( \@path );
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
    }

    return 1;    
            
}
 
1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Connector::GetValue

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
and the name of the current realm with C<PKI_REALM>.
This is effective only if ds_key_param or the named context value is not set.

=item ds_key_prefix

A prefix to prepend to the key

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

=item ds_value_map

If your connector returns a hash of values, you must use C<ds_value_map>
instead of C<ds_value_param> to define a mapping. The syntax is:

    context_name1 => connector_name1, context_name2 => connector_name2  

Default value and wantarray are ignored.

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
    ds_value_map="puk"
    ds_wantarray="0"> 	
    
    <field name="token_id" label="Serial number of Smartcard"/>
  </action>

