#!/usr/bin/perl -w
#
# Written by Petr Grigoriev the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project
# $Revision$
#


use strict;
use warnings;
use utf8;
use English;
use Encode;
use XML::Simple;
use Pod::Usage;
use Getopt::Long;
use Locale::Messages qw (:locale_h :libintl_h nl_putenv bind_textdomain_filter);
use POSIX qw (setlocale);
use Image::Size 'html_imgsize';
				  


# command line options
my $man      = 0;
my $help     = 0;
my $html     = 0;

# file name for the website document
my $html_name = 'workflow-graphs.html';

#default i18n language
my $language = "en_GB";

# default list of workflow definitions
# assumed to be in the corresponding SVN directory
my $wf_all   = '../../trunk/deployment/etc/templates/default/workflow.xml'; 

# default directory for html pages and pictures
# assumed to be in the corresponding SVN directory (website leaf) 
my $dot_dir  = '../../www.openxpki.org/trunk/src/htdocs/docs/wf-pictures';

my $pic_format = 'png';

if( GetOptions(      'help|?' => \$help,
                        'man' => \$man,
		      'def=s' => \$wf_all,
		'directory=s' => \$dot_dir,
		   'format=s' => \$pic_format,
                     'lang=s' => \$language,
		       'html' => \$html,
               )
  ){
    pod2usage(1) if $help;
    pod2usage(-exitstatus => 0, -verbose => 2) if $man;
} else {
  print STDERR "See manual: wf_grapfs.pl --man\n"; exit 0;
};
#print "LANGUAGE <".$language.">\n"; exit 1;
my $loc = "${language}.UTF-8";
setlocale(LC_MESSAGES, $loc);
setlocale(LC_TIME,     $loc);
nl_putenv("LC_MESSAGES=$loc");
nl_putenv("LC_TIME=$loc");
textdomain ('openxpki');
bindtextdomain ('openxpki' => '/usr/local/share/locale');
bind_textdomain_codeset("openxpki", "UTF-8");
#my $msg=gettext ("I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_LOGIN_FAILED");
#print STDERR $msg."\n";
#exit 1;

#print STDERR $dot_dir."\n"; exit 1;

#subdirectory for html references
my $ref_dir = $dot_dir;
$ref_dir =~ s/^.*\///;

# call for a graphviz picture creator
my $genpic = "dot -T" . $pic_format . " -o ";

# get directory with workflow definitions
# it assumed to be the same as the directory with definition list
# if wf_all is /x/y/z then def_dir is /x/y/
#
my $def_dir = $wf_all;
   $def_dir =~ s/[^\/]*$//;

#print STDERR $def_dir."\n";exit 1;  

# get a list of workflow definitions
my $config = XMLin($wf_all);

my $wf_config = $config->{'workflows'}->{'configfile'};
if($html){
   open(WEBFILE, ">", $dot_dir ."/../". $html_name ) or 
        die "Opening file $html_name in $dot_dir:  $!";
   print WEBFILE "<%attr>\n";
   print WEBFILE "title => 'OpenXPKI workflows graphical representation'\n";
   print WEBFILE "</%attr>\n\n";
   print WEBFILE "<h1>OpenXPKI workflows' graphical representation</h1>\n";
   print WEBFILE "<p>\n";
   print WEBFILE "Here are links to graphs describing main OpenXPKI workflows\n";
   print WEBFILE "</p>\n\n"
};
foreach my $wf_file (@{$wf_config}){
   my $wf_def = $wf_file;
#  cut path - we assume it must be the same as in wf_all 
   $wf_def =~ s/^.*\///;

#  dot file has the same name but suffix 'dot' instead of 'xml'
   my $wf_dot = $wf_def;
   $wf_dot =~ s/xml$/dot/; 

#  build a full path to workflow definition file
   $wf_def = $def_dir . $wf_def;

#  we get workflow title after parsing it's definition   
   my $wf_title='';
   my $data=wf_visualize($wf_def,\$wf_title);
#   print STDERR "TITLE ". $wf_title."\n";
   $wf_title = gettext($wf_title);
   print STDERR "Processing <".$wf_title.">\n";
   
#  now we build the full path to dot-file and create it   
   my $dot_file= $dot_dir . "/" . $wf_dot;
   open(DOTFILE, ">:encoding(UTF8)", $dot_file ) or 
        die "Opening file $wf_dot in $dot_dir:  $!";
   print DOTFILE $data;
   close(DOTFILE);

#  create graphviz command line and compile a picture   
   my $generator = 
         $genpic . " " . $dot_file . "." . $pic_format . " < " . $dot_file;
   my $picture_done=`$generator`; 

#  create html file with the picture and write a link to it
#  to the main html file   
   if($html){
      open(WEBLINKFILE, ">", $dot_file . ".html") or 
        die "Opening file $dot_file" . ".html in $dot_dir:  $!";
      print WEBLINKFILE "<%attr>\n";
      print WEBLINKFILE "title => 'OpenXPKI workflows graphical representation'\n";
      print WEBLINKFILE "</%attr>\n\n";
      print WEBLINKFILE "<h1>OpenXPKI workflows' graphical representation</h1>\n";
      print WEBLINKFILE "<h2> Workflow ". $wf_title ."</h2>\n\n";
      print WEBLINKFILE "<p>\nAutorun states are yellow\n</p>\n\n";
      print WEBLINKFILE "<p>\n".
            "You may need to pan or scroll to view a picture\n</p>\n\n";
      print WEBLINKFILE "<p>\n";
      my $image_name = $dot_file . "." . $pic_format;
      my $image_size = html_imgsize($image_name);
      # $size == 'width="60" height="40"'

      print WEBLINKFILE '<img hspace=5 align="left" ' . $image_size .
                        ' src="'. $wf_dot . '.' . $pic_format . '"' .
			' border=0 '.
			'alt="' . $wf_title . '" ' .
			'title="' . $wf_title . '" ' .
			'/>'."\n"; 
      print WEBLINKFILE '<br clear="all"/></p>' . "\n";
      close(WEBLINKFILE);
      print WEBFILE '<a href="' . $ref_dir . '/' . $wf_dot . '.html">' .
                    $wf_title . '</a><br/>'."\n";    			
   };
};

if($html){ 
   close(WEBFILE);
};

exit 1;


sub wf_visualize
{
 my $wf_xml = shift;
 my $wf_title = shift;
 my %wf_parsed = wfparse($wf_xml);
 my $wf = \%wf_parsed;

 #return type for picture caption in html file
 ${$wf_title}=$wf->{'type'};

 my $data = wf_make_graph($wf);
 return $data;
}

sub wf_make_graph
{
my $wf = shift; 

# Configuration variables for special states colors
my $SUCCESS_STATE = 'SUCCESS';
my $SUCCESS_COLOR = 'darkgreen';
my $FAILURE_STATE = 'FAILURE';
my $FAILURE_COLOR = 'firebrick';
my $AUTORUN_COLOR = '"yellow"';

my $type=$wf->{'type'};
my $data=get_preamble($type);

my $nodes="";
my $edges="";				
foreach my $state (keys %{$wf->{'states'}}){
 $nodes .= "$state ";
 if(defined $wf->{'states'}->{$state} ->{'autorun'}){
      $nodes .= "[ fillcolor = ".$AUTORUN_COLOR."];\n";
 } else {
      $nodes .= ";\n";
 };
 if( defined $wf->{'states'}->{$state}->{'actions'}){
     foreach my $action (keys    %{$wf->{'states'}->
		              {$state}->{'actions'}}
   	                ){
	 my $edge_label=' [label="'.$action;			
         my $result=$wf->
	       {'states'}->{$state}->
	       {'actions'}->{$action}->{'result'}; 				
         $edges .= $state ." -> ".$result;
         if( defined $wf->{'states'}->
		     {$state}->{'actions'}->
	             {$action}->{'conditions'}){
	     $edge_label .='\\n if ';			
             foreach my $condition (keys   %{$wf->
			              {'states'}->{$state}->
				     {'actions'}->{$action}->
			          {'conditions'}}){
		$edge_label .= " $condition \\n ";	  
             };	 
         };
         $edges .= $edge_label .'"];'."\n";
     };	 
 };	       
};	
# finalize the graphic file
$data .= $nodes;
$data .= $edges;
$data .= "}\n";
return $data;
}

sub wfparse
{
my $wf_xml=shift;
$config = XMLin($wf_xml);
my $wf = {};

my $wf_type = $config->{'type'};
# print "TYPE $wf_type \n";
$wf->{'type'} = $wf_type;
$wf->{'states'} = {};
my $wf_states = $config->{'state'};
foreach my $state (keys %{$wf_states}){
# print "  STATE $state";
 $wf->{'states'}->{$state} = {};
 my $autorun = $wf_states->{$state}->{'autorun'};
 if(defined $autorun){
#    print "   AUTORUN $autorun \n"; 
    $wf->{'states'}->{$state} ->{'autorun'}='yes';
 } else {
#    print "\n";  	 
 };   
 my $state_actions = $wf_states->{$state}->{'action'};
 if( ref($state_actions) ne 'HASH'){
#    print "    NO ACTIONS\n";
 } else {
	 $wf->{'states'}->{$state}->{'actions'} = {};  
   	 if( defined $state_actions->{'name'}){
             my $resulting_state = 
	        $state_actions->{'resulting_state'};
	     my $name = 
	        $state_actions->{'name'};
	     my $conditions =
	        $state_actions->{'condition'};
#	     print "     ACTION $name \n";
#	     print "       RESULTING STATE $resulting_state \n";
             $wf->{'states'}->{$state}->{'actions'}->{$name} = {};  
	     $wf->{'states'}->
	            {$state}->
		 {'actions'}->
		     {$name}->{'result'} = $resulting_state;  
             if( defined $conditions ){ 
                 $wf->{'states'}    -> {$state} ->
	              {'actions'}   -> {$name}  ->
	              {'conditions'} = {};  
                 if( defined $conditions->{'name'}){
                     my $condition = $conditions->{'name'};
#	             print "         CONDITION $condition \n";
	             $wf->{'states'}     -> {$state}->
	                  {'actions'}    -> {$name}->
		          {'conditions'} -> {$condition} = 'if';  
                 } else {
        	      foreach my $condition (keys %{$conditions}){
#	                 print "         CONDITION $condition \n";
		         $wf->{'states'}     -> {$state}->
	                      {'actions'}    -> {$name}->
		              {'conditions'} -> {$condition} = 'if';  

     		      }; 
	         };	    
              };   
         } else {	      
           foreach my $action (keys %{$state_actions}){	 
#              print "      ACTION $action \n";  	 
	      my $resulting_state = 
	         $state_actions->{$action}->{'resulting_state'};
  	      my $conditions = 
	         $state_actions->{$action}->{'condition'};
#	      print "         RESULTING STATE $resulting_state \n";
              $wf->{'states'}->{$state}->{'actions'}->{$action} = {}; 
	      $wf->{'states'}->
	             {$state}->
		  {'actions'}->
		    {$action}->{'result'} = $resulting_state;  
	      if( defined $conditions ){ 
		  $wf->{'states'}    -> {$state} ->
	               {'actions'}   -> {$action}  ->
	               {'conditions'} = {};  
	         if( defined $conditions->{'name'}){
                     my $condition = $conditions->{'name'};
#	             print "         CONDITION $condition \n";
	             $wf->{'states'}     -> {$state}->
	                  {'actions'}    -> {$action}->
		          {'conditions'} -> {$condition} = 'if';  
                 } else {
        	     foreach my $condition (keys %{$conditions}){
#	                 print "         CONDITION $condition \n";
	                 $wf->{'states'}     -> {$state}->
	                     {'actions'}    -> {$action}->
		             {'conditions'} -> {$condition} = 'if';  
	 	     };	 
     		 }; 
	      };
           };  
      }; 
 };
};
return %{$wf};
}

sub get_preamble {
    my $type = shift;
$type = '"'.gettext($type).'"';
my $label = $type;
my $RANKDIR     = '"TB"'; #rank direction, LR or TB (left to right or top to bottom)
my $RATIO       = 0.71; # useful for A4 paper
my $ROTATE      = 0;    # either 0 or 90
my $GRAPH_FONTNAME = '"Futura-CondensedMedium"';
my $GRAPH_FONTSIZE = 24;
my $LABEL_LOCATION = "b"; # t for top or b for bottom
my $MARGIN         = 1;
my $NODE_SHAPE     = '"rect"';
my $NODE_STYLE     = '"filled"';
my $NODE_FONTNAME  = $GRAPH_FONTNAME;
my $NODE_FONTSIZE  = 16;
my $EDGE_FONTNAME  = $GRAPH_FONTNAME;
my $EDGE_FONTSIZE  = 16;

my $preamble ="digraph $type" . " {\n".
              "graph [ rankdir=$RANKDIR,".
                        "ratio=$RATIO,".
		       "rotate=$ROTATE,".
		       "center=1,".
		     "fontname=$GRAPH_FONTNAME,".
		     "fontsize=$GRAPH_FONTSIZE,".
		    "labeljust=c,".
		     "labelloc=$LABEL_LOCATION,".
		       "margin=$MARGIN,".
		        "label=$label".
			"\n];\n".
                  "node [shape=$NODE_SHAPE,".
                        "style=$NODE_STYLE,".
		     "fontname=$NODE_FONTNAME,".
		     "fontsize=$NODE_FONTSIZE".
		     "];\n".
               "edge [fontname=$EDGE_FONTNAME,".
                     "fontsize=$EDGE_FONTSIZE".
			"];\n";
return $preamble;			
}

1;


__END__

=head1 NAME

wf_graphs.pl - workflow graph generator

=head1 USAGE

wf_graphs.pl [options] 

 Options:
   --help                brief help message
   --man                 full documentation
   --html                create html files for website
                         with links to pictures
   --directory <dir>     create pictures in directory 'dir'
   --def <file>          use 'file' as a list of workflow
                         definitions
   --format <type>       format of the graphics files to be created
                         (use only types supported by graphviz)
   --lang <locale>       locale to print picture captions
                         supports en_GB and de_DE

=head1 DESCRIPTION

B<wf_graphs.pl> creates dot-files for graphviz program
to create pictures of all workflow types
specified in the files with workflow definitions.
B<workflow.xml> is used by default as a list of files
with workflow definitions which will be processed.
Workflow definition files are being parsed and then the corresponding
dot-files for graphviz are created. Autorun states are marked yellow.
Using I18N translations is supported for B<en_GB> (default) and B<de_DE>.
Definition files are supposed to have 'xml'
extension. Names for dot-files are built by substituting
extension 'dot' instead of 'xml'. After dot-files are created
graphviz B<dot> utility is called to create pictures in desirable format.
Optionally html-files with links to pictures are created in the same directory
and the main html-file with link list of workflow types in the parent directory.

The name of the main html-file is predefined: B<workflow-graphs.html>

The default list of workflow definitions is assumed to be 
in the corresponding SVN directory:

 ../../trunk/deployment/etc/templates/default/workflow.xml 

Default directory for html pages and pictures is
assumed to be in the corresponding SVN directory (website leaf) 

 ../../www.openxpki.org/trunk/src/htdocs/docs/wf-pictures

=head1 OPTIONS

=over 6

=item B<--man>

Use it to read all the manual

=item B<--help>

Use it to get information on command line options only

=item B<--html>

Creates html file 'workflow-graphs.html' and child 
html-pages with pictures.

=item B<--directory> dir

Makes it possible to create dot-files in another directory.
If B<--html> option is used html-files with pictures will also be
created in the given directory but the main html-file with links to
picture pages will be created in the parent directory.

=item B<--def> file

Use 'file' as a list of workflow definitions which will
be processed to create their graphs. The file format must be
the same as in OpenXPKI workflow.xml:

 <workflow_config id="default">
  <workflows>
    <configfile>workflow_def_1.xml</configfile>
    <configfile>workflow_def_2.xml</configfile>
    ...........................................
  </workflows>
 ..............................................
 </workflow_config> 

The path of the specified file will be used to search 
workflow-definitions files.

=item B<--format> type

Generate graphics files in B<type> format.
As B<dot> is called only formats supported by B<graphviz>
make sense. 

=item B<--lang> locale

Uses B<locale> to select language for picture captions.
Supports en_GB and de_DE translations of OpenXPKI tags.
Assumes i18n is installed in /usr/local/share/locale. 

=back

=head1 Built-in-functions

=over 6

=item B<wf_visualize>

Calls wfparse and wf_make_graph for passed filename with
workflow definitions. Returns the output of wf_make_graph.
Writes the workflow type to the variable which link is
passed to the function as the second parameter .

=item B<wf_make_graph>

Creates data to write in dot-file using passed hash with workflow
definitions. Autorun states are marked yellow.

=item B<get_preamble>

Creates a header of the dot-file and returns it.
The only argument is used as a label for the picture.
Picture options are concentrated in this function.

=item B<wfparse>

Parses the passed xml-file with workflow definitions and creates
a hash with those definitions. Returns the hash.

An example is self-explanatory:

 {  'type' => 'WORKFLOW TYPE',
  'states' => { 
      'STATE_1' => {
          autorun => 'yes',
          actions => { 
	     'ACTION_1' => {
	         'result'     => 'RESULTING_STATE_1',
		 'conditions' => { 
		     'CONDITION_1' => 'if',           
		     'CONDITION_2' => 'if',           
                 },
	     },
	     'ACTION_2' => {
	         'result'     => 'RESULTING_STATE_2',
		 'conditions' => { 
		     'CONDITION_3' => 'if',           
		     'CONDITION_4' => 'if',           
                 },
	     },
      },
      'STATE_2' => {
          autorun => 'yes',
          actions => { 
	     'ACTION_3' => {
	         'result'     => 'RESULTING_STATE_3',
		 'conditions' => { 
		     'CONDITION_5' => 'if',           
		     'CONDITION_6' => 'if',           
                 },
	     },
	     'ACTION_4' => {
	         'result'     => 'RESULTING_STATE_4',
		 'conditions' => { 
		     'CONDITION_7' => 'if',           
		     'CONDITION_8' => 'if',           
                 },
	     },
      },
 }

=back

=head1 Examples

To get pictures of the current SVN-snapshot go to the directory
where wf_graphs is stored ( tools/automated_wf_visual ) and say:

 ./wf_graphs.pl --directory .
 
Set of dot-files and png-pictures will be created in the current
directory. 
 
To update pictures of the current SVN snapshot in the website 
source directory (new set of files must be then registered with svn 
B<add> and B<delete> commands):

 ./wf_graphs.pl --html
 
 
 

=cut
