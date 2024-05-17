package OpenXPKI;
use strict;
use warnings;

use OpenXPKI::VERSION;
our $VERSION = $OpenXPKI::VERSION::VERSION;

use Import::Into;

=head1 NAME

OpenXPKI - Base module to reduce boilerlate code in our packages.

=head1 SYNOPSIS

    use OpenXPKI;

    # Inheritance
    use OpenXPKI -base => 'Net::Server::MultiType';
    use OpenXPKI qw ( -base Net::Server::MultiType );

    # Moose class
    use OpenXPKI -class;
    use OpenXPKI qw( -class -nonmoose );
    use OpenXPKI qw( -class -typeconstraints );
    use OpenXPKI qw( -class -exporter );

    # Moose role
    use OpenXPKI -role;

    # API plugin
    use OpenXPKI -plugin;

=cut

sub import {
    my $class = shift;
    my ($caller_pkg, $caller_file, $caller_line) = caller;

    my %flags;
    while (my $flag = shift) {
        $flags{$flag} = $flag eq '-base' ? shift : 1;
    }

    my $poc_base = delete $flags{-base};
    my $moose_class = delete $flags{-class};
    my $moose_exporter = delete $flags{-exporter};
    my $moose_typeconstraints = delete $flags{-typeconstraints};
    my $moose_nonmoose = delete $flags{-nonmoose};
    my $moose_role = delete $flags{-role};
    my $plugin = delete $flags{-plugin};
    $moose_class = 1 if ($plugin and not $moose_class and not $moose_role);

    die sprintf(
        'Unknown options: "use OpenXPKI qw( ... %s )" (called at %s line %s)',
        join(' ', keys %flags), $caller_file, $caller_line
    ) if scalar keys %flags;

    # import required modules and pragmas into the calling package

    # Moose
    if ($moose_class or $moose_role) {
        if ($moose_class) {
            Moose->import::into(1);
            MooseX::NonMoose->import::into(1) if $moose_nonmoose;
        } else {
            Moose::Role->import::into(1);
        }
        Moose::Exporter->import::into(1) if $moose_exporter;
        Moose::Util::TypeConstraints->import::into(1) if $moose_typeconstraints;
    # Plain old Perl package / class
    } else {
        base->import::into(1, $poc_base) if $poc_base;
        strict->import::into(1);
        warnings->import::into(1);
    }

    # API plugin
    if ($plugin) {
        OpenXPKI::Base::API::Plugin->import::into(1);
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
        bareword_filehandles
    ));

    # Core modules
    Data::Dumper->import::into(1);
    Scalar::Util->import::into(1, qw( blessed ));

    # CPAN modules
    Type::Params->import::into(1, qw( signature_for ));

    # Project modules
    OpenXPKI::Debug->import::into(1);
    OpenXPKI::Dumper->import::into(1);
    OpenXPKI::Exception->import::into(1);
    OpenXPKI::Util->import::into(1);

    # Disable "experimental" warnings: should be done after other imports to safely disable warnings in Perl < 5.36
    warnings->unimport::out_of(1, qw(
        experimental::isa
        experimental::signatures
    ));

    # try {...} catch ($e) {...} - should be done after other imports to safely disable warnings
    Feature::Compat::Try->import::into(1); # use Feature::Compat::Try

}

=head1 DESCRIPTION

When using this package various pragmas and modules are imported into the
calling package via L<Import::Into>.

=head2 Plain Perl package/class

    use OpenXPKI;

This is equivalent to adding the following imports to the calling package:

    use strict;
    use warnings;
    use utf8; # allows for UTF-8 characters within the source code
    use English;

    # Language features
    use feature "current_sub";
    use feature "isa";
    use feature "say";
    use feature "signatures";
    use feature "state";
    no feature "indirect";
    no feature "multidimensional";
    no feature "bareword_filehandles";

    # Core modules
    use Data::Dumper;
    use Scalar::Util "blessed";

    # CPAN modules
    use Type::Params "signature_for";
    use Feature::Compat::Try;

    # Project modules
    use OpenXPKI::Debug;
    use OpenXPKI::Exception;
    use OpenXPKI::Util;

=head2 Perl class with inheritance

    use OpenXPKI -base => 'Net::Server::MultiType';

adds C<use base qw( Net::Server::MultiType )> to the list of imports.

=head2 Moose class

    use OpenXPKI -class;

This adds C<use Moose> to the list of imports.

=head2 Moose class with type constraints

    use OpenXPKI qw( -class -typeconstraints );

This adds C<use Moose> and C<Moose::Util::TypeConstraints> to the list of imports.

=head2 Moose exporter class

    use OpenXPKI qw( -class -exporter );

This adds C<use Moose> and C<use MooseX::Exporter> to the list of imports.

=head2 Moose class extending a non-Moose class

    use OpenXPKI qw( -class -nonmoose );

This adds C<use Moose> and C<use MooseX::NonMoose> to the list of imports.

=head2 Moose role

    use OpenXPKI -role;

This adds C<use Moose::Role> to the list of imports.

=head2 Moose exporter role

    use OpenXPKI qw( -role -exporter );

This adds C<use Moose::Role> and C<use MooseX::Exporter> to the list of imports.

=head2 Imports

=head3 use feature "current_sub"

New C<__SUB__> token that returns a reference to the current subroutine
or undef outside of a subroutine.

=head3 use feature "isa"

New C<isa> infix operator:

    if ($o isa 'OpenXPKI::Exception') {
        ...
    }

Also see L<https://perldoc.perl.org/feature#The-'isa'-feature>.

=head3 use feature "say"

New C<say> function which behaves like C<print> with a trailing newline:

    say "Yay";

Also see L<https://perldoc.perl.org/feature#The-'say'-feature>.

=head3 use feature "signatures"

Enable subroutine signatures:

    sub message ($self, $a, $b) {
        ...
    }

Also see L<https://perldoc.perl.org/feature#The-'signatures'-feature>.

=head3 use feature "state"

New C<state> keyword:

    sub do_things {
        # will be set on first call to do_things() and preserved
        state $log = Log::Log4perl->get_logger();
        ...
    }

Also see L<https://perldoc.perl.org/feature#The-'state'-feature>.

=head3 no feature "indirect"

Disable indirect object syntax:

    use OpenXPKI::Server::Session;

    my $sess = OpenXPKI::Server::Session->new; # ok
    my $sess = new OpenXPKI::Server::Session;  # dies

Also see L<https://perldoc.perl.org/feature#The-'indirect'-feature>.

=head3 no feature "multidimensional"

Disable auto conversion of e.g. C<$foo{$x, $y}> into C<$foo{join($;, $x, $y)}>
(this was a Perl 4 feature).

Also see L<https://perldoc.perl.org/feature#The-'multidimensional'-feature>.

=head3 no feature "bareword_filehandles"

Disable bareword filehandles for builtin functions operations:

    open my $fh, '>', $file; # ok
    open FH, '>', $file;     # dies

Also see L<https://perldoc.perl.org/feature#The-'bareword_filehandles'-feature>.

=head3 use Data::Dumper

New C<Dumper> function:

    $self->log->trace(Dumper $obj) if $self->log->is_trace;

=head3 use Scalar::Util "blessed"

New C<blessed> function:

    if (blessed $result) {
        ...
    }

=head3 use Type::Params "signature_for"

New C<signature_for> function:

    signature_for merge => (
        method => 1,
        named => [
            into     => 'Str',
            set      => 'HashRef',
            set_once => 'Optional[ HashRef ]', { default => {} },
            where    => 'HashRef[Value]',
        ],
    );
    sub merge ($self, $arg) {
        if ($arg->set_once) ...
    }

Also see L<https://metacpan.org/pod/Type::Params#signature_for-$function_name-=%3E-(-%25spec-)>.

=head3 use Feature::Compat::Try

Try/catch control flow:

   try {
      attempt_a_thing();
      return "success";
   }
   catch ($e) {
      warn "It failed - $e";
      return "failure";
   }

Also see L<https://metacpan.org/pod/Feature::Compat::Try>.

=head3 OpenXPKI modules

=over

=item * L<OpenXPKI::Debug>

=item * L<OpenXPKI::Exception>

=item * L<OpenXPKI::Util>

=back

=cut

1;
