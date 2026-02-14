package OpenXPKI;
use strict;
use warnings;

use OpenXPKI::VERSION;
our $VERSION = $OpenXPKI::VERSION::VERSION;

use Import::Into;
use List::Util qw( any );

=head1 NAME

OpenXPKI - Base module to reduce boilerlate code in our packages.

=head1 SYNOPSIS

    use OpenXPKI;

    # Moose class
    use OpenXPKI -class;
    use OpenXPKI qw( -class -nonmoose );
    use OpenXPKI qw( -class -typeconstraints );
    use OpenXPKI qw( -class -exporter );
    use OpenXPKI qw( -class -insideout );
    use OpenXPKI qw( -class -nonmoose -insideout );

    # Moose role
    use OpenXPKI -role;

    # Simple Perl class with inheritance
    use OpenXPKI -parent => 'Net::Server::MultiType'; # alias for -base
    use OpenXPKI -base   => 'Net::Server::MultiType';
    use OpenXPKI qw ( -base Net::Server::MultiType ); # same

    # Class::Std class
    use OpenXPKI -class_std;

    # API plugin
    use OpenXPKI -plugin;

    # Client API plugin
    use OpenXPKI -client_plugin;

    # WebUI Data Transfer Object
    use OpenXPKI -dto;

=cut

sub import {
    my $class = shift;
    my ($caller_pkg, $caller_file, $caller_line) = caller;

    my %flags;
    while (my $flag = shift) {
        # -base and -parent must be followed by the name of the base class
        $flags{$flag} = (any { $flag eq $_ } ('-base', '-parent')) ? shift : 1;
    }

    # -parent is an alias for -base
    $flags{-base} = delete $flags{-parent} if exists $flags{-parent};

    my $poc_base;
    if (exists $flags{-base}) {
        $poc_base = delete $flags{-base} # $poc_base = name of base class
          or die sprintf 'Missing base class after "use OpenXPKI -base" called at %s line %s'."\n", $caller_file, $caller_line;
    }

    my $dto = delete $flags{-dto}; # WebUI DTO
    my $moose_class = delete $flags{-class} || $dto;
    my $moose_exporter = delete $flags{-exporter};
    my $moose_typeconstraints = delete $flags{-typeconstraints};
    my $moose_strictconstructor = delete $flags{-strictconstructor} || $dto;
    my $moose_nonmoose = delete $flags{-nonmoose};
    my $moose_insideout = delete $flags{-insideout};
    my $moose_role = delete $flags{-role};
    my $class_std = delete $flags{-class_std};
    my $plugin = delete $flags{-plugin};
    my $client_plugin = delete $flags{-client_plugin};
    my $types = delete $flags{-types};
    $moose_class = 1 if (($plugin or $client_plugin) and not $moose_role);

    die sprintf(
        'Unknown options in "use OpenXPKI qw( ... %s )" called at %s line %s'."\n",
        join(' ', keys %flags), $caller_file, $caller_line
    ) if scalar keys %flags;

    # import required modules and pragmas into the calling package

    # Moose
    if ($moose_class or $moose_role) {
        if ($moose_class) {
            Moose->import::into(1);
            if ($moose_insideout) {
                if ($moose_nonmoose) {
                    MooseX::NonMoose::InsideOut->import::into(1);
                } else {
                    MooseX::InsideOut->import::into(1);
                }
            } else {
                MooseX::NonMoose->import::into(1) if $moose_nonmoose;
            }
        } else {
            Moose::Role->import::into(1);
        }
        Moose::Exporter->import::into(1) if $moose_exporter;
        MooseX::StrictConstructor->import::into(1) if $moose_strictconstructor;

    # Plain old Perl package / class
    } else {
        Class::Std->import::into(1) if $class_std;
        if ($poc_base) {
            # "use Mojo::Base ..." for Mojolicious parents so that e.g.
            # Mojolicious' has() is imported.
            if ($poc_base =~ /^Mojolicious::/) {
                Mojo::Base->import::into(1, $poc_base);
            # otherwise: "use parent ..."
            } else {
                parent->import::into(1, $poc_base);
            }
        }
        strict->import::into(1);
        warnings->import::into(1);
    }

    # -typeconstraints may be used standalone without -class in a pure
    # type container package (looking at you, OpenXPKI::Types).
    Moose::Util::TypeConstraints->import::into(1) if $moose_typeconstraints;

    # API plugin
    if ($plugin or $client_plugin) {
        OpenXPKI::Base::API::Plugin->import::into(1);
        OpenXPKI::Client::API::Plugin->import::into(1) if $client_plugin;
    }

    # WebUI Data Transfer Object
    if ($dto) {
        OpenXPKI::Client::Service::WebUI::Response::DTO->import::into(1);
    }

    utf8->import::into(1);
    English->import::into(1);

    # Enable language features: use feature qw( ... )
    feature->import::into(1, qw(
        current_sub
        isa
        say
        signatures
        state
    ));

    # Disable language features: no feature qw( ... )
    feature->unimport::out_of(1, qw(
        indirect
        multidimensional
    ));
    feature->unimport::out_of(1, qw(
        bareword_filehandles
    )) if "$]" > 5.036;

    # Core modules
    Data::Dumper->import::into(1);
    Scalar::Util->import::into(1, qw( blessed ));

    # CPAN modules
    Type::Params->import::into(1, qw( signature_for signature ));

    # Project modules
    OpenXPKI::Debug->import::into(1);
    OpenXPKI::Dumper->import::into(1);
    OpenXPKI::Exception->import::into(1);
    OpenXPKI::Util->import::into(1);
    OpenXPKI::Types->import::into(1) if $types;
    OpenXPKI::Defaults->import::into(1);

    # Disable "experimental" warnings: should be done after other imports to safely disable warnings in Perl < 5.36
    warnings->unimport::out_of(1, qw(
        experimental::isa
        experimental::signatures
    ));

    # try {...} catch ($e) {...} - should be done after other imports to safely disable warnings
    Feature::Compat::Try->import::into(1); # use Feature::Compat::Try

}

1;

__END__

=head1 DESCRIPTION

When using this package various pragmas and modules are imported into the
calling package via L<Import::Into>.

    use OpenXPKI;

This adds the following imports to the calling package:

=head2 Pragmas

    use strict;
    use warnings;
    use utf8; # allows for UTF-8 characters within the source code
    use English;

=head2 Language features

=head3 C<use feature "current_sub";>

=over

=item

C<__SUB__> token that returns a reference to the current subroutine
or undef outside of a subroutine.

=back

=head3 C<use feature "isa";>

=over

=item

C<isa> infix operator
(L<see Perldoc|https://perldoc.perl.org/feature#The-'isa'-feature>):

    if ($o isa 'OpenXPKI::Exception') {
        ...
    }

=back

=head3 C<use feature "say";>

=over

=item

C<say> function which behaves like C<print> with a trailing newline
(L<see Perldoc|https://perldoc.perl.org/feature#The-'say'-feature>):

    say "Yay";

=back

=head3 C<use feature "signatures";>

=over

=item

Enable subroutine signatures
(L<see Perldoc|https://perldoc.perl.org/feature#The-'signatures'-feature>):

    sub message ($self, $a, $b) {
        ...
    }

=back

=head3 C<use feature "state";>

=over

=item

C<state> keyword
(L<see Perldoc|https://perldoc.perl.org/feature#The-'state'-feature>):

    sub do_things {
        # will be set on first call to do_things() and preserved
        state $log = Log::Log4perl->get_logger();
        ...
    }

=back

=head3 C<no feature "indirect";>

=over

=item

Disable indirect object syntax (L<see Perldoc|https://perldoc.perl.org/feature#The-'indirect'-feature>):

    use Dummy;
    my $d;
    $d = Dummy->new; # ok
    $d = new Dummy;  # dies

=back

=head3 C<no feature "multidimensional";>

=over

=item

Disable auto conversion of e.g. C<$foo{$x, $y}> into C<$foo{join($;, $x, $y)}>
(this was a Perl 4 feature, L<see Perldoc|https://perldoc.perl.org/feature#The-'multidimensional'-feature>).

=back

=head3 C<no feature "bareword_filehandles";>

=over

=item

Disable bareword filehandles for builtin functions operations
(L<see Perldoc|https://perldoc.perl.org/feature#The-'bareword_filehandles'-feature>):

    open my $fh, '>', $file; # ok
    open FH, '>', $file;     # dies

=back

=head2 Modules for syntax enhancement and helpers

=head3 C<use Data::Dumper;>

=over

=item

Provides function C<Dumper()>:

    $self->log->trace(Dumper $obj) if $self->log->is_trace;

=back

=head3 C<use Scalar::Util "blessed";>

=over

=item

Provides function C<blessed()>:

    if (blessed $result) {
        ...
    }

=back

=head3 C<use Type::Params qw( signature_for signature );>

=over

=item

Provides function C<signature_for()> (see L<Type::Params|https://metacpan.org/pod/Type::Params#signature_for-$function_name-=%3E-(-%25spec-)>):

    signature_for merge => (
        method => 1,
        named => [
            into     => 'Str',
            set      => 'HashRef',
            set_once => 'Optional[ HashRef ]', { default => {} },
        ],
    );
    sub merge ($self, $arg) {
        if ($arg->set_once) ...
    }

C<signature_for()> does not work with Moose's around modifier (anymore), so we
have to use C<signature()> in that case.

    around compute => sub ($orig, $self, @args) {
        state $sig = signature(
            named => [
                keys      => 'ArrayRef',
                bitlength => 'Optional[ Num ]',
            ],
        );
        my ($arg) = $sig->(@args);
        ...
    };

=back

=head3 C<use Feature::Compat::Try;>

=over

=item

Provides C<try>/C<catch> control flow (see L<Feature::Compat::Try|https://metacpan.org/pod/Feature::Compat::Try>):

   try {
      attempt_a_thing();
      return "success";
   }
   catch ($e) {
      warn "It failed - $e";
      return "failure";
   }

=back

=head2 OpenXPKI modules

=head3 L<C<use OpenXPKI::Debug;>|OpenXPKI::Debug>

=head3 L<C<use OpenXPKI::Exception;>|OpenXPKI::Exception>

=head3 L<C<use OpenXPKI::Util;>|OpenXPKI::Util>

=head3 L<C<use OpenXPKI::Defaults;>|OpenXPKI::Defaults>

=head1 OPTIONS

=head2 Moose class

    use OpenXPKI -class;
    extends 'OpenXPKI::XYZ';

    ### adds these imports:
    # use Moose;

=head3 ...with type constraints

    use OpenXPKI qw( -class -typeconstraints );

    ### adds these imports:
    # use Moose;
    # use Moose::Util::TypeConstraints;

=head3 ...with strict constructor

    use OpenXPKI qw( -class -strictconstructor );

    ### adds these imports:
    # use Moose;
    # use MooseX::StrictConstructor;

=head3 ...with exporter

    use OpenXPKI qw( -class -exporter );

    ### adds these imports:
    # use Moose;
    # use Moose::Exporter;

=head3 ...extending non-Moose class

    use OpenXPKI qw( -class -nonmoose );

    ### adds these imports:
    # use Moose;
    # use MooseX::NonMoose;

=head3 ...inside-out

    use OpenXPKI qw( -class -insideout );

    ### adds these imports:
    # use Moose;
    # use MooseX::InsideOut;

=head3 ...inside-out, extending non-Moose class

    use OpenXPKI qw( -class -nonmoose -insideout );

    ### adds these imports:
    # use Moose;
    # use MooseX::NonMoose::InsideOut;

=head2 Moose role

    use OpenXPKI -role;

    ### adds these imports:
    # use Moose::Role;

=head3 ...with exporter

    use OpenXPKI qw( -role -exporter );

    ### adds these imports:
    # use Moose::Role;
    # use MooseX::Exporter;

=head2 Simple Perl class with inheritance

    use OpenXPKI -base   => 'Net::Server::MultiType';
    use OpenXPKI -parent => 'Net::Server::MultiType'; # alias for -base

    ### adds these imports:
    # use parent qw( Net::Server::MultiType );

=head2 C<Class::Std> class

    use OpenXPKI -class_std;

    ### adds these imports:
    # use Class::Std;

=head2 API plugin

    use OpenXPKI -plugin;

    ### adds these imports:
    # use Moose;
    # use OpenXPKI::Base::API::Plugin;

=head2 Client API plugin

    use OpenXPKI -client_plugin;

    ### adds these imports:
    # use Moose;
    # use OpenXPKI::Base::API::Plugin;
    # use OpenXPKI::Client::API::Plugin;

=head2 WebUI Data Transfer Object

    use OpenXPKI -dto;

    ### adds these imports:
    # use Moose;
    # use MooseX::StrictConstructor;
    # use OpenXPKI::Client::Service::WebUI::Response::DTO;

=cut
