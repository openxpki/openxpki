
use strict;
use warnings;

package OpenXPKI::Client::HTML::Mason::Menu;

use OpenXPKI::Exception;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = shift; ## includes CONFIG and ROLE

    bless $self, $class;

    if (not exists $self->{ROLE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CLIENT_HTML_MASON_MENU_NEW_MISSING_ROLE");
    }
#print STDERR "Role:::: ".$self->{ROLE}."\n";
#use Data::Dumper;
#print STDERR Dumper($self->{CONFIG});
#print STDERR Dumper($self->{CONFIG}->{ROLE});
    if (not exists $self->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CLIENT_HTML_MASON_MENU_NEW_MISSING_CONFIG");
    }
    if (not exists $self->{CONFIG}->{ROLE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CLIENT_HTML_MASON_MENU_NEW_MISSING_ROLE_CONFIG");
    }
    if (not exists $self->{CONFIG}->{ROLE}->{$self->{ROLE}})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CLIENT_HTML_MASON_MENU_NEW_WRONG_ROLE",
            params  => {ROLE => $self->{ROLE}});
    }

    return $self;
}

sub __calculate
{
    my $self   = shift;
    my @path   = @_;
    my @top    = ();
    my $return = "";

    my $level = 0;
    while (my $item = shift @path)
    {
        $return .= $self->__get_level (
                   {
                       LEVEL    => $level,
                       SELECTED => $item,
                       PATH     => [ @top ]});
        push @top, $item;
        $level++;
    }
    ## active menu layer
    $return .= $self->__get_level ({LEVEL => $level, PATH => [ @top ]});
    return $return;
}

sub __get_level
{
    my $self   = shift;
    my $params = shift;
    my $level  = $params->{LEVEL};
    my $select = $params->{SELECTED};

    ##! 2: "determine menu for level $level"
    my $menu = "";
    if ($level == 0)
    {
        my $role = $self->{ROLE};
        ##! 4: "ROLE ::= $role"
        $menu = $self->{CONFIG}->{ROLE}->{$role}->{MENU};
    } else {
        ## menus are not security relevant
        ## so it is safe to not check the input from the browser
        $menu = $select;
    }
    ##! 2: "MENU ::= $menu"

    ##! 2: "calculate the different items"
    my $return = "";
    $return .= "<div class=\"menu_level_$level\">\n";
    for (my $i = 0; $i < scalar @{$self->{CONFIG}->{MENU}->{$menu}}; $i++)
    {
        ##! 4: "i ::= $i"
        my $type  = $self->{CONFIG}->{MENU}->{$menu}->[$i]->[0];
        my $label = $self->{CONFIG}->{MENU}->{$menu}->[$i]->[1];
        my $name  = $self->{CONFIG}->{MENU}->{$menu}->[$i]->[2];
        ##! 4: "type=$type;$label=$label;name=$name"
        ## ok das msste man komplett in die Parameterklasse einbauen
        if ($type eq "MENU")
        {
            if ($menu eq $name)
            {
                $return .= "  <div class=\"menu_level_${level}_item_type_active_menu\">\n";
            } else {
                $return .= "  <div class=\"menu_level_${level}_item_type_menu\">\n";
            }
            $return .= "    <a href=\"".
                       $self->get_menu_link (
                       {
                           "PATH"  => $params->{PATH},
                           "MENU"  => $name
                       }).
                       "\">\n";
        } else {
            $return .= "  <div class=\"menu_level_${level}_item_type_action\">\n";
            $return .= "    <a href=\"".
                       $self->get_menu_link (
                       {
                           "PATH"   => $params->{PATH},
                           "ACTION" => $name
                       }).
                       "\">\n";
        }
        $return .= "      $label\n";
        $return .= "    </a>\n";
        $return .= "  </div>\n";
    }
    $return .= "</div>\n";

    ##! 1: "end"
    return $return;
}

sub get_menu_link
{
    my $self   = shift;
    my $params = shift;
    my @path   = @{$params->{PATH}};
    ## plus ACTION or MENU

    ## URL zusammenbauen via url.mhtml
}

sub get
{
    my $self = shift;
    return $self->__calculate( @_ );
}

1;
