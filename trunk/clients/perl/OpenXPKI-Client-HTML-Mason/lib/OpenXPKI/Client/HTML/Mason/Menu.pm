
use strict;
use warnings;

package OpenXPKI::Client::HTML::Mason::Menu;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = shift;

    bless $self, $class;

    return $self;
}

sub __calculate
{
    my $self   = shift;
    my $return = "";

    my $level = 0;
    while ($self->{PARAMS}->get_param ({"LAYER" => "MENU", "NAME" => "LEVEL_$level"}))
    {
        $return .= $self->__get_level ({LEVEL => $level});
        $level++;
    }
    ## active menu layer
    $return .= $self->__get_level ({LEVEL => $level});
    return $return;
}

sub __get_level
{
    my $self   = shift;
    my $params = shift;
    my $level = $params->{LEVEL};

    ##! 2: "determine menu for level $level"
    my $menu = "";
    if ($level == 0)
    {
        my $role = $self->{PARAMS}->get_param ({"LAYER" => "SESSION",
                                                "NAME"  => "ROLE"});
        #print STDERR "ROLE ::= $role\n";
        $menu = $self->{CONFIG}->{ROLE}->{$role}->{MENU};
    } else {
        ## menus are not security relevant
        ## so it is safe to not check the input from the browser
        $menu = $self->{PARAMS}->get_param ({"LAYER" => "MENU",
                                             "NAME"  => "LEVEL_".($level-1)});
    }
    ## print "MENU ::= $menu\n";

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
            if ($self->{PARAMS}->get_param ({"LAYER" => "MENU",
                                             "NAME"  => "LEVEL_".($level)}))
            {
                $return .= "  <div class=\"menu_level_${level}_item_type_active_menu>\n";
            } else {
                $return .= "  <div class=\"menu_level_${level}_item_type_menu>\n";
            }
            $return .= "    <a href=\"".
                       $self->{PARAMS}->get_menu_link (
                       {
                           "LAYER" => "MENU",
                           "LEVEL" => $level,
                           "MENU"  => $name
                       }).
                       "\">\n";
        } else {
            $return .= "  <div class=\"menu_level_${level}_item_type_action>\n";
            $return .= "    <a href=\"".
                       $self->{PARAMS}->get_menu_link (
                       {
                           "LAYER"  => "ACTION",
                           "LEVEL"  => $level,
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

sub get
{
    my $self = shift;
    return $self->__calculate();
}

1;
