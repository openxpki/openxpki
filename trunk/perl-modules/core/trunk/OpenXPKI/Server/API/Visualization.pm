## OpenXPKI::Server::API::Visualization.pm 
##
## Written 2006 by Michael Bell and Alex Klink for the OpenXPKI project
## Copyright (C) 2006 by The OpenXPKI Project

package OpenXPKI::Server::API::Visualization;

use strict;
use warnings;
use utf8;
use English;

use OpenXPKI::FileUtils;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::i18n;

use Class::Std;

### Configuration variables
### TODO: this should be moved to an (XML) configuration file

my $SUCCESS_STATE = 'SUCCESS';

my $SUCCESS_COLOR = 'darkgreen';

my $FAILURE_STATE = 'FAILURE';

my $FAILURE_COLOR = 'firebrick';

my $AUTORUN_STYLE = 'dashed';

## replaced LR by TB for better printing and smaller paper sizes
my $RANKDIR     = ""; # GraphViz's rank direction, either LR or TB
                        # (left to right or top to bottom)

my $RATIO       = 0.71; # useful for A4 paper
my $ROTATE      = 0;    # either 0 or 90
my $GRAPH_FONTNAME = "Futura-CondensedMedium"; # use a condensed font where
                                               # possible
my $GRAPH_FONTSIZE = 24;
my $LABEL_LOCATION = "b"; # t for top or b for bottom
my $MARGIN         = 1;

my $NODE_SHAPE     = "rect";
my $NODE_STYLE     = "filled";
my $NODE_FONTNAME  = $GRAPH_FONTNAME;
my $NODE_FONTSIZE  = 16;

my $EDGE_FONTNAME  = $GRAPH_FONTNAME;
my $EDGE_FONTSIZE  = 8;

sub START {
    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED',
    );
}

sub get_workflow_instance_info {
    my $self  = shift;
    my $args  = shift;

    ##! 1: "get_workflow_instance_info"

    my $wf_id  = $args->{ID};
    my $format = $args->{FORMAT};
    my $data   = "";
    OpenXPKI::i18n::set_language ($args->{LANGUAGE});

    ##! 2: "prepare preamble of graphic file"

    my $list = CTX('dbi_workflow')->select ( TABLE   => "WORKFLOW",
                                             SERIAL  => $wf_id );
    my $wf_type = $list->[0]->{WORKFLOW_TYPE};
    ##! 4: "WF_TYPE: $wf_type"
    $data .= __get_preamble ({ID => $wf_id, TYPE => $wf_type});

    ##! 2: "load the different workflow steps"

    $list = CTX('dbi_workflow')->select ( TABLE   => "WORKFLOW_HISTORY",
                                          DYNAMIC => {"WORKFLOW_SERIAL" => $wf_id});

    my $nodes .= qq{    NEW [label="NEW"]\n};
    my $edges = "";
    my %states = (NEW => 1);

    foreach my $item (@{$list})
    {
        my $action    = $item->{WORKFLOW_ACTION};
        my $user      = $item->{WORKFLOW_USER};
        my $old_state = $item->{WORKFLOW_STATE};
        my $new_state = $item->{WORKFLOW_DESCRIPTION};
        my $time      = $item->{WORKFLOW_HISTORY_DATE};
        my $autorun;

        if ($new_state =~ /NEW_STATE_AUTORUN/)
        {
            $new_state =~ s/^.*NEW_STATE_AUTORUN:\s*//;
            $autorun = 1;
        }
        elsif ($new_state =~ /NEW_STATE/)
        {
            $new_state =~ s/^.*NEW_STATE:\s*//;
        }
        else {
            $old_state = "NEW";
            $new_state = "INITIAL";
        }
        my $i18n_old_state = OpenXPKI::i18n::i18nGettext($old_state);
        my $i18n_new_state = OpenXPKI::i18n::i18nGettext($new_state);
        my $i18n_action    = OpenXPKI::i18n::i18nGettext($action);

        ##! 4: "build the node"
        $nodes .= qq{    $new_state [label="$i18n_new_state"};

        if ($new_state eq $SUCCESS_STATE) {
            $nodes .= ",fillcolor=$SUCCESS_COLOR";
        }
        elsif ($new_state eq $FAILURE_STATE) {
            $nodes .= ",fillcolor=$FAILURE_COLOR";
        }
        $nodes .= qq{]\n};

        ##! 4: "build the edge"
        $edges .= "    $old_state -> $new_state [label=".
                  '"'.$i18n_action.'\nby '.$user.'\n'.$time.'\n\n"'; ## trailing newlines are for better output
        if ($autorun || $old_state eq "INITIAL") {
            # INITIAL is implicit autorun
            $edges .= qq{,style="$AUTORUN_STYLE"};    
        }
        $edges .= "];\n";
    }

    ##! 2: "finalize the graphic file"

    $data .= $nodes;
    $data .= $edges;
    $data .= "}\n";
    ##! 64: $data
 

    if ($format ne "NULL")
    {
        ##! 4: "create image"
        my $fu = OpenXPKI::FileUtils->new();
        my $filename = $fu->get_safe_tmpfile({TMP => CTX('xml_config')->get_xpath(XPATH => 'common/server/tmpdir')});
        if (not open FH, "|dot -T$format > $filename")
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_API_VISUALIZATION_GET_WORKFLOW_INFO_DOT_FAILED");
        }
        print FH $data;
        close FH;
        $data = $fu->read_file($filename);
        ##! 64: $data
    }

    ##! 1: "finished"

    return $data;
}

sub __get_preamble {
    my $arg_ref = shift;

    my $type  = $arg_ref->{TYPE};
    my $id    = $arg_ref->{ID};
    my $label = OpenXPKI::i18n::i18nGettext ($type);

    return "digraph $type" . '_' . "$id {\n".
           qq{    graph [rankdir=$RANKDIR,ratio=$RATIO,rotate=$ROTATE,center=1,fontname="$GRAPH_FONTNAME",fontsize=$GRAPH_FONTSIZE,labeljust=c,labelloc=$LABEL_LOCATION,margin=$MARGIN,label="$label\\n$id"];\n}.
           qq{    node [shape="rect",style="filled",fontname="Futura-CondensedMedium",fontsize=16];\n}.
           qq{    edge [fontname="Futura-CondensedMedium",fontsize=8];\n};
}

1;
__END__

=head1 Name

OpenXPKI::Server::API::Visualization

=head1 Description

The API bundles all functions to output graphics related to the
handling of the PKI workflow. Generally spoke, it implements
.dot files for the GraphViz package.

=head1 Functions

=head2 get_workflow_instance_info

It accepts the parameter ID which is the ID of the workflow
whose history should be visualized. Additionally, FORMAT specifies
the output format of the graph and LANGUAGE can be used to output
the graph in one of the supported languages.

Please see the GraphViz package for more details.
