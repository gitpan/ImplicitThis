package ImplicitThis;

use 5.6.0;
use strict;

our $VERSION = '0.01_001';
$VERSION = eval $VERSION;  # see L<perlmodstyle>

# ImplicitThis - 
# Modify a package to implicitly take "this" as a first argument, and to access
# object fields by default.

# to use, in your code, do:

# use ImplicitThis; ImplicitThis::imply();

# does anyone know how to hand the CPU back after we finish loading, but take it 
# again when whomever used us finishes loading?

sub import {
  my $callerpackage = caller;
  no strict 'refs';
  
  *{$callerpackage.'::caller'} = sub {
    my $lev = shift() || 0; 
    # account for the ::imply() generated wrapper, and account for this function here
    $lev += 2; 
    return CORE::caller($lev);
  };

}

sub imply {

  my $callerpackage = caller;

  no strict 'refs';
  no strict 'vars';
  no strict 'subs';

  # loop over symbols in their name table, finding things that are functions

  for $i (grep { defined &{$callerpackage.'::'.$_} } keys %{$callerpackage.'::'}) {

    next if $i eq 'new';
    next if $i eq 'caller';

    my $funname = $i; 
    my $funfun = \&{$callerpackage.'::'.$i}; # reference to pre-modified code 

    # make a new code reference. give it the same name. lexically bind it to the old reference.

    *{$callerpackage.'::'.$funname} = sub {
      my $this = shift;
      my $newcp = caller;

      if(substr($funname, 0, 1) eq '_') {
        # we're supposed to be private. see to the fact.
        caller(0) eq $callerpackage or
          die sprintf "Cannot invoke private method %s from outside %s",
            $funname, __PACKAGE__;
      }
      
      @ISA = @{$newcp.'::ISA'}; # become one of whatever called us

      # create a $this local that contains the pointer to the object the method
      # was called in. this lets people say things like: $this->get_foo();
      # XXX to emulate "normal" instance variable access, we could AUTOLOAD and
      # XXX treat $this->var as a method call, translating it to $this->{'var'}

      local *{$callerpackage.'::this'};
      *{$callerpackage.'::this'} = \$this;

      # give the same treatment to each instance variable: localize it for safety,
      # then make it an alias to the hash entry that contains the instance variable.

      my @fields = keys %$this;
      my $field;

      FIELDS:

        $field = shift @fields;

        local *{$callerpackage.'::'.$field};
        *{$callerpackage.'::'.$field} = \$this->{$field};
  
      goto FIELDS if(@fields);

      # goto &$funfun; # this wont work because it immediately restores all variables we localized
      # we just have to deal with a bogus stack frame lingering

      # invoke the code reference that we've secret replaced ourselves with.

      $funfun->(@_);

      # *now* local variables get restored

    }
  }
}

1;

1;
__END__

=head1 NAME

ImplicitThis - Syntactical Sugar for OO Methods

=head1 SYNOPSIS

  use ImplicitThis; ImplicitThis::imply();

  sub new {
    my $type = shift;
    my %args = @_;
    # must be blessed hash object
    bless { 
      foo => $args{'foo'},
      bar => $args{'bar'},
    }, $type;
  }

  sub my_accessor {
    # $this is read for us. $bar is aliased to $this->{'bar'}, similiar for $foo
    $this->another_accessor($bar);
    $foo++;
  }

  sub _another_accessor {
    # this will die if called from something not derived from our package
    $foo++;
  }

=head1 ABSTRACT

  Methods in OO Perl receive "$this" without having to read it.
  Instance field variables are accessable by name instead of having to
  dereference the hash ref. Privicy is enforced for methods starting with
  an understore.

=head1 DESCRIPTION

  This emulates other OO languages, such as Java and C++, where the compiler
  implicitly and invisibly passes "this" as the first argument of each method
  call. While Perl passes this argument invisibly, you must manually write
  code to read it. Java and C++ also discover, at compile time, rather a
  variable is an instance variable or a static variable, without you needing
  to distinguish them using special syntax. We remove the extra syntax, but
  this is learned at run time, not compile time. Unlike Alias.pm, this code
  is likely to have a noticable impact on performance of code that uses OO
  accessors heavily.

  ImplicitThis::imply() places a thin wrapper is placed around methods in your 
  object. *this{SCALAR}
  is a reference to a lexical we've shifted off the argument list.
  Aliases are created for each key in %$this to itself value in the
  same way.

  While this module works fine for me, your milage may very: it has not
  been extensively tested.

  Similar to Alias.pm. However, we're pure Perl, and _no_ additional
  syntax is introduced. 
  
  Blah blah blah.

=head2 EXPORT

None.

=head1 BUGS

Does anyone know how to hand the CPU back after we finish loading, but take it 
again when whomever used us finishes loading?

Doesn't work with strict on without doing "use vars" on each field member. Bummer. 

Not sure which version of perl is the minimum required.

May confuse highly introspective perl, like anything Damian Conway might write.

Does not work correctly when instance variables are tied: the alias doesn't currently
take on the tiedness. In some cases, tie $alias, ref $this->{$alias} would do the
trick. This would fail on limited resources and when tie requires arguments.

=head1 SEE ALSO

Just a cheep knock-off of Alias.pm by Gurusamy Sarathy.

For more examples and documentation, as well as forums, Perl Design Patterns, see: 
http://www.slowass.net/wiki/


=head1 AUTHOR

Scott Walters "Root of all Evil" E<lt>scott@slowass.netE<gt>
SWALTERS on CPAN

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Scott Walters

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. Should you, through neglect or
fault, speak the same phrase concurrently with another party, you realize that
use of this software requires compliances with the rules governing the game of "jinx".

=cut
