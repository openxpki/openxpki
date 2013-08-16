#!/usr/bin/env perl -w
#
# ogflow.pl - Convert OmniGraffle File to Workflow Definition
#
# This script converts an OmniGraffle flowchart into an XML
# document for the Workflow module.
#
# TODO:
#
# Add code to reject conditions after actions -- there must be a state
# between them.
#
# Since OmniGraffle doesn't really understand the structure of our XML
# definition files, there are many assumptions that must be adhered to
# for this to work properly.
#
# In the "Document Description" (via the inspector), enter the unique
# identifier for your workflow (e.g.: SMARTCARD_PERS). This is then
# used for the I18N identifiers and the names of the output XML files.
#
# The following objects in the OG document are supported
#
# Shape:
#
#   RoundRect = activity
#
# The following XML objects are written:
#
# state definitions (<state>)
#
#   name = text field from graphics object
#   autorun = set "autorun" to "yes" in the key/value table for the object
#   description = 'workflow i18n prefix' + name
#   actions = action objects that this connects to
#       name = name of action
#       resulting_state = state that action points to
#       condition = name of condition
#
# activities (<action>)
#
#   In "Properties: Note" in the inspector, the data key/values specified
#   are appended to the <action name="yourname" ..." entity.
#
#   Use the key "class" to specify the perl class for this action. If left empty,
#   "Workflow::Actions::Null" is used.
#
#   Additional parameters for the
#   perl module may be specified here. Note: these are static parameters
#   for this action.
#
#   Fields (workflow instance arguments) may be specified in the first
#   and second cells of the table object. These are comma-separated lists.
#   The first cell specifies mandatory fields, whereas those in the second
#   cell are optional.
#
#
# conditions (<condition>)
#
#   In "Properties: Note" in the inspector, the data key/values specified
#   are added to the entity as <param> items. The key is the param name
#   and the value is the value of the parameter.
#
#   Use the key "class" to specify the perl class for this condition.
#
# goto (an upside down house shape used to go to another page)
#
#   When a link is coming from another page, just specify the name of the
#   page on one line. These objects will be ignored during the processing.
#
#   When a link goes to another page, specify the page name and resulting
#   state name, separated with a colon, followed by a line feed (":<line feed>").
#
# Usage:
#
#  ogflow.pl FILENAME
#
# Notes:
#
# asXml gets called when the object type is the primary type for the output
# file. For example, when creating workflow_def_<wfname>.xml, asXml gets called
# on the type 'state'. If it is a sub-type of the current output, as<wftype>Xml
# gets called. The type 'state' for example, can also be a child of another state.
# In this case, there is an implicit 'action' and calling asStateXml on the 'state'
# object returns the '<action name="null" resulting_state="<this state>"</action>'.

use strict;

use Mac::PropertyList;
use Data::Dumper;
use Carp;
use Cwd;

my $showUnknown = 1;
my $docVersion = '';    # from document data
my $docSubject = '';    # from document data
my $descPrefix  = 'DOC_DESC_NOT_SET';
my $i18nPrefix  = 'I18N_OPENXPKI_WF';
my $indentSpace = ' ' x 4;

my $namespace = '';
my $verbose   = 0;

my $force = 1;
warn "WARN: force is with you\n";

my $sheetnum = 1;

our $objs               = {};
our $connsByFromId      = {};
our $condLabelsByLineId = ();

our $maxNull = 0;

# This is the base class for the following shape (non-line objects)
package WF::Shape;
use Class::InsideOut qw( public readonly private register id );
public notes => my %shape_notes;
public sheet => my %shape_sheet;
public oid   => my %shape_oid;
public text  => my %shape_text;

sub fqname {
    my $self = shift;
    # If text does not start with 'I18N', prepend the namespace
    if ( $self->text =~ /^I18N/ ) {
        return $self->text;
    } else {
        return $namespace . $self->text;
    }
}

sub equals {
    my ( $a, $b ) = @_;
    foreach my $k (qw( notes text )) {
        if ( ( not defined $a->$k ) and ( not defined $b->$k ) ) {
            return 1;
        }
        elsif ( ( not defined $a->$k ) or ( not defined $b->$k ) ) {
            return;
        }
        elsif ( $a->$k ne $b->$k ) {
            warn "equals() field $k doesn't match:\n",
                "Obj A: ", $a->dumpPretty( indent => 1 ),
                "Obj B: ", $b->dumpPretty( indent => 1 );
            return;
        }
    }
    return 1;
}

sub dump {
    my $self = shift;

    #    my @ret = map { $_, ( $_[0]->$_ ? $_[0]->$_ : '<undef>' ) }
    #        qw( type oid sheet text );
    my @ret = "Object: "
        . join( ' ',
        map { "$_=" . ( $self->$_ ? $self->$_ : '<undef>' ) }
            qw( type oid sheet text ) );

    #    my @ret = "Object: type=" . $self->type
    #        . " oid=" . $self->oid
    #        . " sheet=" . $self->sheet
    #        . " text=" . $self->text;
    if ( exists $connsByFromId->{ $self->sheet }->{ $self->oid } ) {
        push @ret, 'Connections: '
            . join( ', ',
            @{ $connsByFromId->{ $self->sheet }->{ $self->oid } } );

#        foreach ( @{ $connsByFromId->{ $self->sheet }->{ $self->oid } } ) {
#            push @ret, map { "\t" . $_ } $objs->{ $self->sheet }->{$_}->dump;
#        }
    }

    return @ret;
}

sub dumpPretty {
    my $self   = shift;
    my %p      = @_;
    my @ret    = $self->dump;
    my $indent = $p{indent} || 0;
    return ( "\t" x $indent ) . join( "\n" . "\t" x $indent, @ret ) . "\n";
}

sub children {
    my $self         = shift;
    my $line2lineFix = 0;
    my @ret          = ();

    if ( exists $connsByFromId->{ $self->sheet }->{ $self->oid } ) {
        foreach my $connLine ( map { $objs->{ $self->sheet }->{$_} }
            @{ $connsByFromId->{ $self->sheet }->{ $self->oid } } )
        {
            my $nextObj = $objs->{ $connLine->sheet }->{ $connLine->to };

            if ( not defined $nextObj ) {
                Carp::cluck "Internal error (object id ", $connLine->to,
                    " not found) processing object:\n",
                    $self->dumpPretty( indent => 1 ),
                    "Line object with missing destination object:\n",
                    $connLine->dumpPretty( indent => 1 );
                next;
            }
            my $obj;

            if ( $nextObj->type eq 'goto' ) {
                push @ret, $nextObj->children;

      #                my $obj;
      #                foreach $obj ( map { values %{$_} } values %{$objs} ) {
      #                    next unless $obj->type eq 'state';
      #                    if ( $obj->text eq $nextObj->state ) {
      #                        push @ret, $obj;
      #                        last;
      #                    }
      #                }
            }
            elsif ( $line2lineFix and $nextObj->type eq 'line' ) {

                # try to skip to next line
                while ( defined $nextObj
                    and $nextObj->type eq 'line'
                    and $nextObj->to )
                {
                    $nextObj = $objs->{ $self->sheet }->{ $nextObj->to };
                }
                push @ret, $nextObj if defined $nextObj;
            }
            else {
                push @ret, $nextObj if $nextObj;
            }
        }
        return @ret;
    }
    else {
        return;
    }
}

package WF::State;
use Class::InsideOut qw( public readonly private register id );
use base 'WF::Shape';
use Data::Dumper;
public userInfo => my %state_userInfo;
sub new  { register(shift) }
sub type { return 'state' }

sub maxNull {
    my $self = shift;
    my $null;
    foreach my $child ( $self->children ) {
        if ( $child->type eq 'state' ) {
            $null++;
            if ( $null > $maxNull ) {
                $maxNull = $null;
            }
        }
        elsif ( $child->type eq 'condition' ) {
            my @actions = $child->listActions;

            # check for null
            foreach my $a (@actions) {
                if ( $a->[0] eq 'null' ) {
                    $null++;
                    if ( $null > $maxNull ) {
                        $maxNull = $null;
                    }
                }
            }
        }
    }
    return $maxNull;
}

sub asXml {
    my $self     = shift;
    my $indent   = shift || 0;
    my @out      = ();
    my $null     = 0;
    my $userInfo = $self->userInfo;

    push @out, $indentSpace x $indent++;
    push @out, '<state name="', $self->text, '"';
    if ( defined $userInfo and ref($userInfo) eq 'HASH' ) {
        foreach my $k ( sort grep { not $_ eq 'class' } keys %{$userInfo} ) {
            push @out, "\n", $indentSpace x ( $indent + 1 ), $k, '="',
                $userInfo->{$k}, '"';
        }
    }

    push @out, '>', "\n";
    push @out, $indentSpace x $indent, '<description>',
        $i18nPrefix, '_STATE_', $descPrefix, '_', $self->text,
        '</description>', "\n";

    foreach my $child ( $self->children ) {
        warn $child->dumpPretty( indent => 1 ) if $verbose;
        if ( $child->type eq 'action' ) {
            push @out, $child->asStateXml($indent);
        }
        elsif ( $child->type eq 'state' ) {
            $null++;
            if ( $null > $maxNull ) {
                $maxNull = $null;
            }
            push @out, $child->asStateXml( $indent, $null );

        }
        elsif ( $child->type eq 'condition' ) {
            my @actions = $child->listActions;

            # check for null
            foreach my $a (@actions) {
                if ( $a->[0] eq 'null' ) {
                    $null++;
                    if ( $null > $maxNull ) {
                        $maxNull = $null;
                    }
                    $a->[0] = 'null' . $null;

                }
            }

            foreach my $rec (@actions) {
                push @out, $indentSpace x $indent, '<action name="',
                    ( $namespace . shift @{$rec} ),
                    '" resulting_state="', shift @{$rec}, '">', "\n";
                foreach my $cond ( @{$rec} ) {
                    push @out, $indentSpace x ( $indent + 1 ),
                        '<condition name="', $cond, '"/>', "\n";
                }
                push @out, $indentSpace x $indent, '</action>', "\n";
            }
        }
        else {
            warn "unsupported child: ", $child->dump;
        }
    }

    $indent--;
    push @out, $indentSpace x $indent;
    push @out, '</state>', "\n";
    return @out;
}

sub asStateXml {
    my $self     = shift;
    my $indent   = shift || 0;
    my $null     = shift || 0;
    my $condName = shift;
    my @out      = ();
    push @out, $indentSpace x $indent, '<action name="', $namespace, 'null',
        $null,
        '" resulting_state="', $self->text, '">', "\n";
    if ( defined $condName ) {
        push @out, $indentSpace x ( $indent + 1 ),
            '<condition name="', $condName, '">', "\n";
    }
    push @out, $indentSpace x $indent, '</action>', "\n";

    return @out;
}

package WF::Condition;
use Class::InsideOut qw( public readonly private register id );
use base 'WF::Shape';
use XML::Simple;
public class  => my %cond_class;
public params => my %cond_params;
sub new  { register(shift) }
sub type { return 'condition' }

sub childLines {
    my $self = shift;
    my @ret  = ();
    if ( exists $connsByFromId->{ $self->sheet }->{ $self->oid } ) {
        foreach my $connLine ( map { $objs->{ $self->sheet }->{$_} }
            @{ $connsByFromId->{ $self->sheet }->{ $self->oid } } )
        {
            push @ret, $connLine;
        }
        return @ret;
    }
    else {
        return;
    }
}

sub asXml {
    my $self   = shift;
    my $indent = shift || 0;
    my @out    = ();
    my $class  = $self->class;    # || 'Class Not Set';

    push @out, $indentSpace x $indent++;
    push @out, '<condition name="', $self->fqname, '"';
    if ($class) {
        push @out,, "\n", $indentSpace x ( $indent + 1 ), 'class="', $class,
            '"';
    }
    push @out, '>', "\n";

    # No, I don't have time at the moment to refactor _everything_
    # to use XML::Simple, but I do need it to escape things like '<='
    # in the parameter values, so here is just a quick hack.
    my $params = $self->params;
    foreach my $k ( keys %{$params} ) {

        #        push @out, $indentSpace x ($indent), '<param name="', $k,
        #            '" value="', $params->{$k}, '"/>', "\n";
        push @out, $indentSpace x ($indent),
            XMLout( { param => { name => $k, value => $params->{$k} } },
            KeepRoot => 1 );
    }

    $indent--;
    push @out, $indentSpace x $indent;
    push @out, '</condition>', "\n";

    return @out;
}

# return a list of actions in the form
#   [ 'actionname', 'resulting state', 'condition1' [ , 'condition2' ...] ]
sub listActions {
    my $self = shift;
    my @ret  = ();
    foreach my $childLine ( $self->childLines ) {

        my $child = $objs->{ $self->sheet }->{ $childLine->to };
        if ( not defined $child ) {
            warn "WARN: destination not defined for line:\n",
                $childLine->dumpPretty;
            next;
        }
        my $val = $condLabelsByLineId->{ $self->sheet }->{ $childLine->oid };
        my $condName = $self->fqname;
        if ( not defined $val ) {
            warn "WARN: Label for line from condition not defined - ",
                $self->dump;
        }
        elsif ( $val eq 'no' ) {
            $condName = '!' . $condName;
        }

        if ( $child->type eq 'action' ) {
            push @ret, [ $child->text, $child->nextState, $condName ];
        }
        elsif ( $child->type eq 'state' ) {
            push @ret, [ 'null', $child->text, $condName ];
        }
        elsif ( $child->type eq 'goto' ) {
            my $obj;
            my $found          = 0;
            my @statesRejected = ();    # for debugging
            foreach $obj (
                map {
                    sort { $a->oid <=> $b->oid }
                        values %{ $objs->{$_} }
                } sort { $a <=> $b } keys %{$objs}
                )
            {
                next unless $obj->type eq 'state';
                if ( $obj->text eq $child->state ) {
                    $found++;
                    push @ret, [ 'null', $obj->text, $condName ];
                    last;
                }
                else {
                    push @statesRejected, $obj->text;
                }
            }
            if ( not $found ) {
                warn "Goto state '", $child->state, "' not found in (",
                    join( ', ', sort @statesRejected ), "): ",
                    $child->dump;
            }
        }
        elsif ( $child->type eq 'condition' ) {
            my @childActions = $child->listActions;
            foreach my $ca (@childActions) {
                push @ret, [ @{$ca}, $condName ];
            }
        }
        else {
            warn "unsupported child: ", $child->dump;
        }
    }
    return @ret;
}

sub asStateXml {
    my $self   = shift;
    my $indent = shift || 0;
    my $null   = shift || 0;
    my @out    = ();
    push @out, $indentSpace x $indent;
    foreach my $childLine ( $self->childLines ) {
        my $child = $objs->{ $self->sheet }->{ $childLine->to };
        my $val = $condLabelsByLineId->{ $self->sheet }->{ $childLine->oid };
        my $condName = $self->text;
        if ( not defined $val ) {
            warn "WARN: Label for line from condition not defined - ",
                $self->dump;
        }
        elsif ( $val eq 'no' ) {
            $condName = '!' . $condName;
        }

        if ( $child->type eq 'action' ) {
            push @out, $child->asStateXml( $indent, $condName );
        }
        elsif ( $child->type eq 'state' ) {
            push @out, $child->asStateXml( $indent, $null, $condName );
        }
        elsif ( $child->type eq 'goto' ) {
            my $obj;
            my $found          = 0;
            my @statesRejected = ();    # for debugging
            foreach $obj (
                map {
                    sort { $a->oid <=> $b->oid }
                        values %{ $objs->{$_} }
                } sort { $a <=> $b } keys %{$objs}
                )
            {
                next unless $obj->type eq 'state';
                if ( $obj->text eq $child->state ) {
                    $found++;
                    push @out, $obj->asStateXml( $indent, $null, $condName );
                    last;
                }
                else {
                    push @statesRejected, $obj->text;
                }
            }
            if ( not $found ) {
                warn "Goto state '", $child->state, "' not found in (",
                    join( ', ', sort @statesRejected ), "): ",
                    $child->dump;
            }
        }
        elsif ( $child->type eq 'condition' ) {
            push @out, '<!-- multi-level condition: ', $child->dump, '-->',
                "\n";
            my @recs = $self->listActions;
            foreach my $rec (@recs) {
                push @out, '<action name="', $namespace . shift @{$rec},
                    '" resulting_state="', shift @{$rec}, '">', "\n";
                foreach my $cond ( @{$rec} ) {
                    push @out, '<condition name="', $cond, '"/>', "\n";
                }
                push @out, '</action>', "\n";
            }
        }
        else {
            warn "unsupported child: ", $child->dump;
        }
    }
    return @out;
}

package WF::Action;
use Class::InsideOut qw( public readonly private register id );
use base 'WF::Shape';
use Data::Dumper;
public userInfo => my %action_userInfo;
public fields   => my %action_fields;
sub new  { register(shift) }
sub type { return 'action' }

sub dump {
    my $self = shift;
    my @ret  = $self->SUPER::dump();
    foreach my $p (qw( userInfo fields )) {
        my $href = $self->$p;
        if ( defined $href ) {
            push @ret, $p . '=(' . join( ', ', %{$href} ) . ')';
        }
    }
    return @ret;
}

sub equals {
    my ( $a, $b ) = @_;
    foreach my $p (qw( userInfo fields )) {

        # use Data::Dumper to serialize before comparing
        my $d1 = Dumper( $a->$p );
        my $d2 = Dumper( $b->$p );
        if ( $d1 ne $d2 ) {
            warn "equals() - field $p: '$d1' ne '$d2'", "\n",
                "Obj A: ", $a->dumpPretty( indent => 1 ),
                "Obj B: ", $b->dumpPretty( indent => 1 );
            return;
        }
    }
    return $a->SUPER::equals($b);
}

sub nextState {
    my $self = shift;
    my @children = grep { ( defined $_ ) and ( $_->type ne 'validator' ) }
        $self->children;
    if ( not scalar @children == 1 ) {
        warn "Actions may only have one child and for this action, I found ",
            scalar @children;
        warn "\tCurrent action: ", $self->dump;
        die "Cannot continue!";
    }
    my $child = $children[0];
    if ( $child->type eq 'state' ) {
        return $child->text;
    }
    return;
}

sub asXml {
    my $self     = shift;
    my $indent   = shift || 0;
    my @out      = ();
    my $null     = 0;
    my $userInfo = $self->userInfo;
    my $fields   = $self->fields;
    my $actionClass;

    if ( defined $userInfo and exists $userInfo->{class} ) {
        $actionClass = $userInfo->{class};
    }
    else {
        $actionClass = 'Workflow::Action::Null';
    }

    push @out, $indentSpace x $indent++;
    push @out, '<action name="', $self->fqname, '"', "\n";
    push @out, $indentSpace x ( $indent + 1 ), 'class="', $actionClass, '"';

    if ( defined $userInfo and ref($userInfo) eq 'HASH' ) {
        foreach my $k ( sort grep { not $_ eq 'class' } keys %{$userInfo} ) {
            push @out, "\n", $indentSpace x ( $indent + 1 ), $k, '="',
                $userInfo->{$k}, '"';
        }
    }
    push @out, ">\n";

    if ( $self->notes ) {
        push @out, $indentSpace x ( $indent + 1 ),
            '<description>', $self->notes, '</description>', "\n";
    }

    if ( defined $fields and ref($fields) eq 'HASH' ) {
        foreach my $k ( sort keys %{$fields} ) {
            push @out, $indentSpace x ( $indent + 1 ),
                '<field name="', $k, '"';
            if ( $fields->{$k} ) {
                push @out, ' is_required="yes"';
            }
            push @out, "/>\n";
        }
    }

    foreach my $val ( grep { $_->type eq 'validator' } $self->children ) {
        push @out, $val->asActionXml( $indent + 1 );
    }

    $indent--;
    push @out, $indentSpace x $indent;
    push @out, '</action>', "\n";
    return @out;
}

# Generates the <action> entity used in the state definition
sub asStateXml {
    my $self     = shift;
    my $indent   = shift || 0;
    my $condName = shift;

    my @children = grep { ( defined $_ ) and ( $_->type ne 'validator' ) }
        $self->children;
    if ( not scalar @children == 1 ) {
        warn
            "Actions must have one and only one child -- for this action, I found ",
            scalar @children;
        warn "Current action: ", $self->dumpPretty( indent => 1 );
        foreach (@children) {
            warn "Connection Details:\n",
                $objs->{ $self->sheet }->{$_}->dumpPretty( indent => 1 );
        }
        if ( exists $connsByFromId->{ $self->sheet }->{ $self->oid } ) {
            warn "Connections: \n";
            foreach ( @{ $connsByFromId->{ $self->sheet }->{ $self->oid } } )
            {
                warn $objs->{ $self->sheet }->{$_}->dumpPretty( indent => 1 ),
                    "\n";
            }
        }
        die "Cannot continue!";
    }
    my @out = ();
    push @out, $indentSpace x $indent;
    push @out, '<action name="', $self->fqname,
        '" resulting_state="', $children[0]->text, '">', "\n";
    if ( defined $condName ) {
        push @out, $indentSpace x ( $indent + 1 ),
            '<condition name="', $namespace . $condName, '">', "\n";
    }
    push @out, $indentSpace x $indent, '</action>', "\n";
    return @out;
}

package WF::Validator;
use Class::InsideOut qw( public readonly private register id );
use base 'WF::Shape';
public args   => my %validator_args;
public class  => my %validator_class;
public params => my %validator_params;
sub new  { register(shift) }
sub type { return 'validator' }

sub asXml {
    my $self   = shift;
    my $indent = shift || 0;
    my @out    = ();
    my $class  = $self->class || 'Class Not Set';

    push @out, $indentSpace x $indent++;
    push @out, '<validator name="', $self->fqname, '"', "\n";
    push @out, $indentSpace x ( $indent + 1 ), 'class="', $class, '">', "\n";
    my $params = $self->params;
    foreach my $k ( keys %{$params} ) {
        push @out, $indentSpace x ($indent), '<param name="', $k,
            '" value="', $params->{$k}, '"/>', "\n";
    }

    $indent--;
    push @out, $indentSpace x $indent;
    push @out, '</validator>', "\n";

    return @out;
}

sub asActionXml {
    my $self   = shift;
    my $indent = shift || 0;
    my @out    = ();

    push @out, $indentSpace x ( $indent + 0 ),
        '<validator name="', $self->fqname, '"';
    my $args = $self->args;
    if ($args) {
        push @out, '>', "\n";
        foreach my $arg ( @{$args} ) {
            push @out, $indentSpace x ( $indent + 1 ),
                '<arg>', $arg, '</arg>', "\n";
        }
        push @out, $indentSpace x ( $indent + 0 ), '</validator>', "\n";
    }
    else {
        push @out, '/>', "\n";
    }

    return @out;
}

package WF::Info;
use Class::InsideOut qw( public readonly private register id );
use base 'WF::Shape';
sub new  { register(shift) }
sub type { return 'info' }

package WF::Goto;
use Class::InsideOut qw( public readonly private register id );
use base 'WF::Shape';
public page  => my %goto_page;
public state => my %goto_state;

sub dump {
    return join( ', ',
        $_[0]->SUPER::dump, map { $_, $_[0]->$_ } qw( page state ) );
}
sub new  { register(shift) }
sub type { return 'goto' }

sub children {
    my $self = shift;
    my @ret  = ();
    my $obj;
    foreach $obj ( map { values %{$_} } values %{$objs} ) {
        next unless $obj->type eq 'state';

        if ( $obj->text eq $self->state ) {
            push @ret, $obj;
            last;
        }
    }

    # if no state object was found, it's an error!
    if ( not @ret ) {
        die "ERROR: no state '", $self->state, "' found for goto object\n";
    }
    return @ret;
}

package WF::Line;
use Class::InsideOut qw( public readonly private register id );
use base 'WF::Shape';
public from => my %line_from;
public to   => my %line_to;

sub dump {
    my @ret = $_[0]->SUPER::dump;
    push @ret, 'From object ' . $_[0]->from . ': ',
        (
        $objs->{ $_[0]->sheet }->{ $_[0]->from } ? map { "\t" . $_ }
            $objs->{ $_[0]->sheet }->{ $_[0]->from }->dump
        : '<unset>'
        ),
        'To object ' . $_[0]->to . ': ',
        (
        $objs->{ $_[0]->sheet }->{ $_[0]->to } ? map { "\t" . $_ }
            $objs->{ $_[0]->sheet }->{ $_[0]->to }->dump
        : '<unset>'
        );
    return @ret;

}
sub new  { register(shift) }
sub type { return 'line' }

package WF::LineLabel;
use Class::InsideOut qw( public readonly private register id );
use base 'WF::Shape';
public lineId => my %linelabel_lineId;

sub dump {
    return
        join( ', ', $_[0]->SUPER::dump, map { $_, $_[0]->$_ } qw( lineId ) );
}
sub new  { register(shift) }
sub type { return 'label' }

package main;

my %link = ();

############################################################
############################################################
##
## Routines for parsing PList structure
##
############################################################
############################################################

sub parseTextVal {
    my $s = shift;

    # remove font/color tables
    $s =~ s/\{\\(font|color)tbl.+?\}\s+//g;

    # convert unicode line/paragraph separator to \n
    $s =~ s/(\\uc0)?\\u8232/\n/g;

    # remove RTF commands
    $s =~ s/\\[^\\\s]+\s*//g;

    # remove brackets at begin and end
    $s =~ s/^\{//;
    $s =~ s/\}$//;

    # remove duplicate spaces
    $s =~ s/\s\s/ /g;

    # remove leading/trailing spaces
    $s =~ s/^\s+//g;
    $s =~ s/\s+$//g;

    # replace single space with underscore
    #   $s =~ s/\s/_/g;

    # remove wierd chars
    $s =~ s/['\?]//g;

    return $s;
}

sub parseGraphicsList {
    my $graphicsList = shift;

    #    print "entered parseGraphicsList($graphicsList)\n";
    foreach my $graphic ( @{$graphicsList} ) {
        my $class;
        if ( exists $graphic->value()->{Class} ) {
            $class = $graphic->value()->{Class}->value();
        }
        if ( $class eq 'ShapedGraphic' ) {
            parseShapedGraphic($graphic);
        }
        elsif ( $class eq 'LineGraphic' ) {
            parseLineGraphic($graphic);
        }
        elsif ( $class eq 'TableGroup' ) {
            parseTableGroup($graphic);
        }
        elsif ($showUnknown) {
            print "WARN: unsupported graphics class '$class'\n";
            print "\t\tID = ", $graphic->value()->{ID}->value(), "\n";
            if ( exists $graphic->value()->{Text} ) {
                my $text = _parseTextVal(
                    $graphic->value()->{Text}->value()->{Text}->value() );
                print "\t\tText = ", $text, "\n";
            }
        }
    }
}

sub parseShapedGraphic {
    my $obj = shift;

    my $id    = $obj->{ID}->value();
    my $shape = $obj->{Shape}->value();
    my $text  = '';
    if ( exists $obj->{Text} and exists $obj->{Text}->value()->{Text} ) {
        $text = parseTextVal( $obj->{Text}->value()->{Text}->value() );
    }
    my $name = $text;
    $name =~ s/\s/_/g;
    $objs->{$sheetnum} ||= {}; # ensure we have a separate dict for each sheet

    if ( exists $objs->{$sheetnum}->{$id} ) {
        warn "ERROR --- Whoa there, Cowboy!\n",
            "just read following object: ShapedGraphic: id=$id, sheet=$sheetnum, shape=$shape, name='$name', text='$text'\n",
            "but we already have that id: ", $objs->{$sheetnum}->{$id}->dump,
            "\n",
            "this can't be true!!!";
    }

    if ( $shape eq 'RoundRect' ) {
        $objs->{$sheetnum}->{$id} = WF::State->new;
        $objs->{$sheetnum}->{$id}->text($name);
        $objs->{$sheetnum}->{$id}->sheet($sheetnum);
        $objs->{$sheetnum}->{$id}->oid($id);
        if ( exists $obj->{UserInfo} ) {
            $objs->{$sheetnum}->{$id}
                ->userInfo( parseUserInfo( $obj->{UserInfo} ) );
        }

    }
    elsif ( $shape eq 'Diamond' ) {
        $name =~ s/\?$//g;    # remove trailing '?'
        $objs->{$sheetnum}->{$id} = WF::Condition->new;
        $objs->{$sheetnum}->{$id}->text($name);
        $objs->{$sheetnum}->{$id}->sheet($sheetnum);
        $objs->{$sheetnum}->{$id}->oid($id);

        if ( exists $obj->{UserInfo} ) {
            my $userInfo = parseUserInfo( $obj->{UserInfo} );
            if ( exists $userInfo->{class} ) {
                $objs->{$sheetnum}->{$id}->class( $userInfo->{class} );
            }
            $objs->{$sheetnum}->{$id}->params(
                {   map { $_, $userInfo->{$_} }
                    grep { $_ ne 'class' } keys %{$userInfo}
                }
            );
        }
    }
    elsif ( $shape eq 'Rectangle' ) {
        if ( exists $obj->{Line} ) {

            # looks like the label of a line
            $objs->{$sheetnum}->{$id} = WF::LineLabel->new;
            $objs->{$sheetnum}->{$id}->text($text);
            $objs->{$sheetnum}->{$id}->sheet($sheetnum);
            $objs->{$sheetnum}->{$id}->oid($id);
            $objs->{$sheetnum}->{$id}
                ->lineId( $obj->{Line}->value()->{ID}->value() );
            $condLabelsByLineId->{$sheetnum}
                ->{ $obj->{Line}->value()->{ID}->value() } = $text;
        }
        else {
            $objs->{$sheetnum}->{$id} = WF::Info->new;
            $objs->{$sheetnum}->{$id}->text($text);
            $objs->{$sheetnum}->{$id}->sheet($sheetnum);
            $objs->{$sheetnum}->{$id}->oid($id);
        }
    }
    elsif ( $shape eq 'House' ) {
        my ( $page, $state ) = split( /:\s*/s, $text );

        if ( defined $state ) {
            $state =~ s/[\s]/_/g;
        }

        #        if ($dest =~ /^[\S+[A
        if ( defined $state ) {
            $state =~ s/ \s/_/g;
            $objs->{$sheetnum}->{$id} = WF::Goto->new;
            $objs->{$sheetnum}->{$id}->text($text);
            $objs->{$sheetnum}->{$id}->sheet($sheetnum);
            $objs->{$sheetnum}->{$id}->oid($id);
            $objs->{$sheetnum}->{$id}->page($page);
            $objs->{$sheetnum}->{$id}->state($state);
        }

    }
    elsif ( $shape eq 'ParallelLines' ) {

        # ignore - from overview on main page
    }

    elsif (( $shape eq 'BevelledRectangle' )
        or ( $shape eq 'FlattenedRectangle' ) )
    {
        my ( $name, $args ) = split( /\n/s, $text, 2 );
        $name =~ s/\s/_/g;
        $objs->{$sheetnum}->{$id} = WF::Validator->new;
        $objs->{$sheetnum}->{$id}->text($name);
        $objs->{$sheetnum}->{$id}->sheet($sheetnum);
        $objs->{$sheetnum}->{$id}->oid($id);
        $objs->{$sheetnum}->{$id}->args( [ split( /\s*, \s*/s, $args ) ] );
        if ( exists $obj->{UserInfo} ) {
            my $userInfo = parseUserInfo( $obj->{UserInfo} );
            if ( exists $userInfo->{class} ) {
                $objs->{$sheetnum}->{$id}->class( $userInfo->{class} );
            }
            $objs->{$sheetnum}->{$id}->params(
                {   map { $_, $userInfo->{$_} }
                    grep { $_ ne 'class' } keys %{$userInfo}
                }
            );
        }
    }
    else {
        print
            "parseShapedGrahic(): Unknown Object - ID=$id, Shape=$shape, text=$text\n";
        return;
    }
    if ( $verbose and defined $objs->{$sheetnum}->{$id} ) {
        warn "Parsed input ($shape): ",
            $objs->{$sheetnum}->{$id}->dumpPretty( indent => 1 );
    }
}

sub parseLineGraphic {
    my $obj = shift;
    my $id  = $obj->{ID}->value();
    my ( $head, $tail );

    if ( not exists $obj->{Head} or not exists $obj->{Tail} ) {

        # missing either head or tail (not sure which is worse ;-)
        # In any case, this line isn't a connection between objects,
        # so we can ignore it.
        return;
    }

    my $headArrow
        = $obj->{Style}->value()->{stroke}->value()->{HeadArrow}->value();
    my $tailArrow
        = $obj->{Style}->value()->{stroke}->value()->{TailArrow}->value();

    $head = $obj->{Head}->value()->{ID}->value();
    $tail = $obj->{Tail}->value()->{ID}->value();

    if ( $headArrow and not $tailArrow ) {
        $objs->{$sheetnum}->{$id} = WF::Line->new;
        $objs->{$sheetnum}->{$id}->oid($id);
        $objs->{$sheetnum}->{$id}->sheet($sheetnum);
        $objs->{$sheetnum}->{$id}->from($tail);
        $objs->{$sheetnum}->{$id}->to($head);
        $connsByFromId->{$sheetnum}->{$tail} ||= [];
        push @{ $connsByFromId->{$sheetnum}->{$tail} }, $id;
        if ($verbose) {
            warn "Parsed input (LineGraphic): ",
                $objs->{$sheetnum}->{$id}->dumpPretty( indent => 1 );
        }
    }
    elsif ( $headArrow and $tailArrow ) {

        # appears to be a two-way connection, which is probably betwen
        # two objects on the overview page and not an action/state/condition
        return;
    }
    else {

        print
            "parseLineGraphic(): Unknown Line - ID=$id, head=$head/$headArrow, tail=$tail/$tailArrow\n";
    }
}

sub parseTableGroup {
    my $obj     = shift;
    my $id      = $obj->{ID}->value();
    my $i       = 0;
    my %cellMap = ();
    my $userInfo;
    my $notes;

    if ( exists $obj->{GridV} ) {

        # This looks like the table of parameters on the last page
        return;
    }

    if ( exists $obj->{Notes} ) {
        $notes = parseTextVal( $obj->{Notes}->value );
    }

    if ( exists $obj->{UserInfo} ) {
        $userInfo = parseUserInfo( $obj->{UserInfo} );
    }

    foreach ( @{ $obj->{GridH}->value() } ) {

        # there seems to be an erroneous array ref that we need to skip
        if ( ref( $_->value() ) ) {
            next;
        }
        $cellMap{ $_->value() } = $i++;
    }

    my @cells     = ();
    my $tableType = 'action';    # assume it's an action

    foreach my $subobj ( @{ $obj->value()->{Graphics}->value() } ) {
        if ( exists $subobj->{ImageID} and ( scalar keys %cellMap ) != 4 ) {
            $tableType = 'info';
        }
        my $cellId = $subobj->{ID}->value();
        my $cellText
            = parseTextVal( $subobj->{Text}->value()->{Text}->value() );
        if ( not exists $cellMap{$cellId} ) {
            print "cellId not in CellMap: ", Dumper($obj), "\n";
        }
        else {
            $cells[ $cellMap{$cellId} ] = $cellText;
        }
    }

    if ( $tableType eq 'action' ) {
        my $name = $cells[0];
        $name =~ s/\s/_/g;
        my $fields = {};

        # split on comma, ignoring 'n/a'
        foreach my $k ( grep { $_ ne 'n/a' } split( /\s*,\s* /, $cells[2] ) )
        {
            $fields->{$k} = 0;
        }

        foreach my $k ( grep { $_ ne 'n/a' } split( /\s*,\s*/, $cells[1] ) ) {
            $fields->{$k} = 1;
        }

        $objs->{$sheetnum}->{$id} = WF::Action->new;
        $objs->{$sheetnum}->{$id}->text($name);
        $objs->{$sheetnum}->{$id}->sheet($sheetnum);
        $objs->{$sheetnum}->{$id}->oid($id);
        $objs->{$sheetnum}->{$id}->notes($notes);
        $objs->{$sheetnum}->{$id}->userInfo($userInfo);
        $objs->{$sheetnum}->{$id}->fields($fields);
        if ($verbose) {
            warn "Parsed input (TableGroup): ",
                $objs->{$sheetnum}->{$id}->dumpPretty( indent => 1 );
        }
    }
    else {

#        warn "tableType = $tableType, id = $id, cells=", scalar keys %cellMap,
#            " (", join( ', ', keys %cellMap ), ')';
    }
}

sub parseUserInfo {
    my $in  = shift;
    my $ret = {};

    foreach my $k ( keys %{ $in->value } ) {
        $ret->{$k} = $in->value->{$k}->value;
    }
    return $ret;
}

############################################################
############################################################
##
## MAIN
##
############################################################
############################################################

use Getopt::Long;

my ( $infile, $outfile, $outtype );

my $result = GetOptions(
    "infile=s"    => \$infile,
    "outfile=s"   => \$outfile,
    "outtype=s"   => \$outtype,
    "verbose"     => \$verbose,
    "namespace=s" => \$namespace,
);

#my $file = $ARGV[0];
$infile ||= $ARGV[0];
if ( -d $infile ) {
    $infile .= '/data.plist';
}

unless ( open FILE, $infile ) {
    die("Could not open $infile");
}

my $data = do { local $/; <FILE> };
close FILE;

my $plist = Mac::PropertyList::parse_plist($data);

if ( $plist->{UserInfo} ) {
    if ( exists $plist->{UserInfo}->value()->{kMDItemDescription} ) {
        $descPrefix
            = $plist->{UserInfo}->value()->{kMDItemDescription}->value();
    }
    if ( exists $plist->{UserInfo}->value()->{kMDItemVersion} ) {
        $docVersion
            = $plist->{UserInfo}->value()->{kMDItemVersion}->value();
    }
    if ( exists $plist->{UserInfo}->value()->{kMDItemSubject} ) {
        $docSubject
            = $plist->{UserInfo}->value()->{kMDItemSubject}->value();
    }
    if ( exists $plist->{UserInfo}->value()->{kMDItemKeywords} ) {
        my $list = $plist->{UserInfo}->value()->{kMDItemKeywords}->value();

        #    warn "list=$list";
        if ( ref($list) ) {
            foreach my $entry ( @{ $list->value() } ) {

                #            warn "entry=$entry => '", $entry->value(), "'";
                if ( $entry->value() =~ m/^namespace=(\S+)$/ ) {
                    $namespace = $1 . '_';
                }
            }
        }
    }
}

if ( exists $plist->{Sheets} ) {

    # first, check whether we need to even parse this sheet
    foreach my $sheet ( @{ $plist->{Sheets}->value() } ) {
        my $parseflag = 1;
        my $bg        = $sheet->value()->{BackgroundGraphic};
        if ( defined $bg ) {
            my $ui = $bg->value()->{UserInfo};
            if ( defined $ui ) {
                my $is = $ui->value->{ignore_sheet};
                if ( defined $ui->value->{ignore_sheet} ) {
                    my $val = $is->value;
                    if ( $val eq 'yes' ) {

                   #                        warn "Skipping sheet $sheetnum\n";
                        $parseflag = 0;
                    }
                }
            }
        }

        if ($parseflag) {

            #            warn "Processing sheet $sheetnum\n";
            parseGraphicsList( $sheet->value()->{GraphicsList} );
        }
        $sheetnum++;
    }
}
else {
    parseGraphicsList( $plist->{GraphicsList} );
}

# quick prototype for gathering git info...
my $olddir = cwd();
my $gitdir = `dirname $infile`;
chomp($gitdir);
chdir($gitdir) || die "Error CD'ing to '$gitdir': $!";
my $gitinfo = `git rev-parse HEAD`;
chomp($gitinfo);
#warn "GITINFO: $gitinfo";
my $gitstatus;
my $git;
open($git, "git status --porcelain|");
if ( not $git ) {
    die "Error running git: $!";
}
while (my $line = <$git>) {
    my ($fstat, $fname) = ($line =~ m/^\s*(\S+)\s+(.+)$/);
    if ( $fname eq $infile ) {
        $gitstatus = $fstat;
        last;
    }
}
close $git;
#warn "GITSTATUS of '$infile': ", $gitstatus;

my %gitlabels = (
    M   => 'modified',
    A   => 'added',
    D   => 'deleted',
    R   => 'renamed',
    C   => 'copied',
    U   => 'updated but unmerged'
);

if ( $gitstatus ) {
    $gitinfo .= ' (' . ($gitlabels{$gitstatus}||$gitstatus) . ')';
}
chdir($olddir) || die "Error CD'ing back to '$olddir': $!";

my $imprint
    = "<!-- \n" 
    . '  Generated by: '
    . $0 . ' '
    . join( ', ', @ARGV ) . "\n\n"
    . '     File: ' . $infile . "\n"
    . '  Version: ' . $docVersion . "\n"
    . '      Git: ' . $gitinfo . "\n"
    . '-->' . "\n\n";

warn "\nGenerating XML output files...\n\n" if $verbose;

############################################################
# Generate state definitions
############################################################
if ( not $outtype or $outtype eq 'states' ) {
    my %states  = ();        # avoid duplicates
    my $defName = $outfile
        || 'workflow_def_' . lc($descPrefix) . '.xml';
    open( DEF, ">$defName" ) or die "Error opening $defName: $!";
    my $indent = 0;
    print DEF $imprint, "\n";
    print DEF $indentSpace x $indent, '<workflow>', "\n";
    $indent++;
    print DEF $indentSpace x $indent, '<type>',
        $i18nPrefix, '_TYPE_', $descPrefix,
        '</type>', "\n";
    print DEF $indentSpace x $indent, '<description>',
        $i18nPrefix, '_DESC_', $descPrefix,
        '</description>', "\n";
    print DEF $indentSpace x $indent,
        '<persister>OpenXPKI</persister>',
        "\n\n";

    foreach my $state (
        sort { $a->oid <=> $b->oid }
        grep { $_->type eq 'state' }
        map { values %{$_} } values %{$objs}
        )
    {

        #        warn "Processing child of ", $state->text, ":\n";
        if ( $states{ $state->text }++ ) {

            if ( $state->children ) {

                # only complain about states that aren't end conditions
                # (like SUCCESS or FAILURE)
                warn "ERROR: state name is not unique in workflow: ",
                    $state->dump;
            }
        }
        else {
            print DEF $state->asXml($indent), "\n";
        }
    }
    $indent--;
    print DEF $indentSpace x $indent, '</workflow>', "\n";
    close DEF;
}

############################################################
# Generate action definitions
############################################################

if ( not $outtype or $outtype eq 'actions' ) {
    my %uniq    = ();
    my $defName = $outfile
        || 'workflow_activity_' . lc($descPrefix) . '.xml';
    open( DEF, ">$defName" ) or die "Error opening $defName: $!";
    my $indent = 0;
    print DEF $imprint, "\n";
    print DEF $indentSpace x $indent, '<actions>', "\n\n";
    $indent++;
    foreach my $rec (
        sort { $a->oid <=> $b->oid }
        grep { $_->type eq 'action' }
        map { values %{$_} } values %{$objs}
        )
    {

        if ( $uniq{ $rec->text } ) {
            if ( not $rec->equals( $uniq{ $rec->text } ) ) {
                die "ERROR: found multiple actions with name '",
                    $rec->text,
                    "' where definition not identical:\n",
                    "\tFirst rec: ", $uniq{ $rec->text }->dump, "\n",
                    "\tSecond rec: ", $rec->dump;
            }
        }
        else {
            $uniq{ $rec->text } = $rec;
            print DEF $rec->asXml($indent), "\n";
        }
    }

    foreach my $state (
        sort { $a->oid <=> $b->oid }
        grep { $_->type eq 'state' }
        map { values %{$_} } values %{$objs}
        )
    {
        $state->maxNull;

    }

    for ( my $i = 1; $i <= $maxNull; $i++ ) {
        print DEF $indentSpace x $indent, '<action name="',
            $namespace,
            'null',                               $i,
            '" class="Workflow::Action::Null"/>', "\n";
    }
    $indent--;
    print DEF $indentSpace x $indent, '</actions>', "\n";
    close DEF;
}

############################################################
# Generate condition definitions
############################################################

if ( not $outtype or $outtype eq 'conditions' ) {
    my %uniq    = ();
    my $defName = $outfile
        || 'workflow_condition_' . lc($descPrefix) . '.xml';
    open( DEF, ">$defName" ) or die "Error opening $defName: $!";
    my $indent = 0;
    print DEF $imprint, "\n";
    print DEF $indentSpace x $indent, '<conditions>', "\n\n";
    $indent++;

    foreach my $rec (
        sort { $a->oid <=> $b->oid }
        grep { $_->type eq 'condition' }
        map { values %{$_} } values %{$objs}
        )
    {
        if ( $uniq{ $rec->text } ) {
            if ( not $rec->equals( $uniq{ $rec->text } ) ) {
                die "ERROR: found multiple actions with name '",
                    $rec->text,
                    "' where definition not identical:\n",
                    "\tFirst rec: ", $uniq{ $rec->text }->dump, "\n",
                    "\tSecond rec: ", $rec->dump;
            }
        }
        else {
            $uniq{ $rec->text } = $rec;
            print DEF $rec->asXml($indent), "\n";
        }
    }
    $indent--;
    print DEF $indentSpace x $indent, '</conditions>', "\n";
    close DEF;
}

############################################################
# Generate validator definitions
############################################################

if ( not $outtype or $outtype eq 'validators' ) {
    my %uniq    = ();
    my $defName = $outfile
        || 'workflow_validator_' . lc($descPrefix) . '.xml';
    open( DEF, ">$defName" ) or die "Error opening $defName: $!";
    my $indent = 0;
    print DEF $imprint, "\n";
    print DEF $indentSpace x $indent, '<validators>', "\n\n";
    $indent++;

    foreach my $rec (
        sort { $a->oid <=> $b->oid }
        grep { $_->type eq 'validator' }
        map { values %{$_} } values %{$objs}
        )
    {
        if ( $uniq{ $rec->text }++ ) {
            warn "ERROR: validator name is not unique in workflow: ",
                $rec->dump;
        }
        print DEF $rec->asXml($indent), "\n";
    }
    $indent--;
    print DEF $indentSpace x $indent, '</validators>', "\n";
    close DEF;
}

