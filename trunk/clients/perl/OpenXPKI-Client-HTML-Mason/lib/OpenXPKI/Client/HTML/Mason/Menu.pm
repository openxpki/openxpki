
use strict;
use warnings;

package OpenXPKI::Client::HTML::Mason::Menu;

use OpenXPKI::Exception;
use OpenXPKI::i18n qw( i18nGettext );
use HTML::Mason::Request; # we only use this because we get $m as parameter

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = shift; ## includes CONFIG and ROLE

    bless $self, $class;

    ## check mason object
    if (not exists $self->{MASON})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CLIENT_HTML_MASON_MENU_NEW_MISSING_MASON");
    }

    ## check session info
    if (not exists $self->{SESSION_ID} and
        not exists $self->{MASON}->request_args()->{"__session_id"})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CLIENT_HTML_MASON_MENU_NEW_MISSING_SESSION_ID");
    }
    if (not exists $self->{ROLE} and
        not exists $self->{MASON}->request_args()->{"__role"})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CLIENT_HTML_MASON_MENU_NEW_MISSING_ROLE");
    }
    $self->__build_env();

    ## check config
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

    ## check info about paths
    if (not exists $self->{COMP})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CLIENT_HTML_MASON_MENU_NEW_MISSING_COMP");
    }
    if (not exists $self->{ACTION})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CLIENT_HTML_MASON_MENU_NEW_MISSING_ACTION");
    }

    return $self;
}

sub __build_env
{
    my $self = shift;
    my %args = $self->{MASON}->request_args();
    delete $self->{PATH} if (exists $self->{PATH});

    ## determine level
    if (exists $args{"__menu_level"})
    {
        $self->{LEVEL} = $args{"__menu_level"};
    } else {
        $self->{LEVEL} = 0;
    }

    ## determine path
    for (my $i=0; $i < $self->{LEVEL}; $i++)
    {
        $self->{PATH}->[$i] = $args{"__menu_item_$i"};
    }

    ## determine session info
    foreach my $key ("SESSION_ID", "ROLE")
    {
        $self->{$key} = $args{"__".lc($key)}
            if (not exists $self->{$key});
    }
    return $self->{LEVEL};
}

sub __get_level
{
    my $self   = shift;
    my $params = shift;
    my $level  = $params->{LEVEL};

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
        $menu = $self->{PATH}->[$level-1];
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
                       $self->__get_menu_link (
                       {
                           "LEVEL" => $level,
                           "MENU"  => $name
                       }).
                       "\">\n";
        } else {
            $return .= "  <div class=\"menu_level_${level}_item_type_action\">\n";
            $return .= "    <a href=\"".
                       $self->__get_menu_link (
                       {
                           "LEVEL"  => $level,
                           "ACTION" => $name
                       }).
                       "\">\n";
        }
        $return .= "      ".i18nGettext($label)."\n";
        $return .= "    </a>\n";
        $return .= "  </div>\n";
        if ($params->{NESTED} and
            $level < $self->{LEVEL} and
            $name eq $self->{PATH}->[$level])
        {
            $return .= $self->__get_level ({LEVEL => $level+1, NESTED => 1});
        }
    }
    $return .= "</div>\n";

    ##! 1: "end"
    return $return;
}

sub __get_menu_link
{
    my $self   = shift;
    my $params = shift;
    my $link   = $self->get_root()."/";

    ## get the menu configuration
    my %result = $self->get_menu_hash ($params);

    ## build the component link
    if ($result{"__menu_action"})
    {
        my $config = $self->{CONFIG}->{ACTION}->{$result{"__menu_action"}};
        $link .= $config->{CMD};
    } else {
        $link .= $self->{ACTION};
    }

    ## include all common parameters
    $link .= "?";
    foreach my $item (keys %result)
    {
        next if (not defined $item);
        next if ($item eq "__menu_action");
        $link .= ";" if (length $link > 1);
        $link .= $item."=".$result{$item};
    }

    ## add parameters for command
    if ($result{"__menu_action"})
    {
        my $config = $self->{CONFIG}->{ACTION}->{$result{"__menu_action"}};
        ## set parameters
        foreach my $param (keys %{$config->{PARAMS}})
        {
            next if (not defined $param);
            if (substr ($param,0, 2) eq "__")
            {
                ## special control parameter
                if (0 > index ($link, $param))
                {
                    ## set value for the first time
                    $link .= ";$param=".$config->{PARAMS}->{$param};
                } else {
                    ## replace original value
                    $link =~ s/$param=[^;]*/$param=$config->{PARAMS}->{$param}/;
                }
            } else {
                $link .= ";__action_param_$param=".$config->{PARAMS}->{$param};
            }
        }
    }

    return $link;
}

sub get_root
{
    my $self = shift;
    my $link = "";

    ## build the correct root component path
    my $pos  = 1; ## ignore first /
    while (length ($self->{COMP}) > $pos)
    {
        my $index = index ($self->{COMP}, "/", $pos);
        last if ($index < $pos);
        $pos   = $index+1;
        $link .= "/" if (length $link);
        $link .= "..";
    }

    return $link;
}

sub get
{
    my $self = shift;

    if ($self->{CONFIG}->{NESTED})
    {
        return $self->__get_level({LEVEL => 0, NESTED => 1});
    } else {
        my $return = "";

        ## get the different menus and submenus
        for (my $i=0; $i <= $self->{LEVEL}; $i++)
        {
            $return .= $self->__get_level ({LEVEL => $i, NESTED => 0});
        }

        return $return;
    }
}

sub get_link_params
{
    my $self   = shift;
    my %params = $self->get_menu_hash();
    my $link   = "";

    foreach my $key (keys %params)
    {
        next if (not defined $key); ## empty array
        $link .= ";" if (length $link);
        $link .= $key."=".$params{$key};
    }
    return $link;
}

sub get_menu_hash
{
    my $self   = shift;
    my $params = shift;
    my $level  = $self->{LEVEL};
       $level  = $params->{LEVEL} if (exists $params->{LEVEL});
    my %link   = ();

    ## add basic path
    $link{__session_id} = $self->{SESSION_ID};
    $link{__role}       = $self->{ROLE};
    $link{__language}   = $self->{LANGUAGE} if (exists $self->{LANGUAGE});
    $link{__menu_level} = $level;
    $link{__menu_level}++ if ($params->{MENU});

    ## build menu path
    for (my $i=0; $i < $level; $i++)
    {
        $link{"__menu_item_$i"} = $self->{PATH}->[$i];
    }

    # complete link
    if (exists $params->{MENU})
    {
        ## this is a menu
        $link{"__menu_item_$level"} = $params->{MENU};
    } else {
        ## this is an action
        $link{"__menu_action"} = $params->{ACTION};
    }

    return %link;
}

1;
__END__

=head1 Name

OpenXPKI::Client::HTML::Mason::Menu

=head1 Description

This module generates the menus for the OpenXPKI web interface.

=head1 Functions

=head2 new

is the constructor and requires the following arguments passed
as hash reference:

=over

=item * MASON - $m from Mason pages

=item * ROLE - required if __role is not set as http parameter

=item * CONFIG - configuration like defined in lib/menu.mhtml

=item * ACTION - the name of the used page in the links

=back

=head2 get

is called without arguments and returns a complete HTML menu.

=head2 get_menu_hash

is usually called with LEVEL as argument and returns a hash which
includes all informations to display the menu if you embed
these values into a link or form. If you call it without the LEVEL
parameter then the complete menu is dumped.

The function get uses this funtion to to build its links.

=head2 get_link_params

returns a line which is ready to be included into an HTML link to get
the actual menu.
