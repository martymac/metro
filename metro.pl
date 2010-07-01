#!/usr/bin/perl

#Copyright (c) 2006, Ganael LAPLANCHE
#All rights reserved.

#Redistribution and use in source and binary forms, with or without modification,
#are permitted provided that the following conditions are met:

#* Redistributions of source code must retain the above copyright notice,
#this list of conditions and the following disclaimer.
#* Redistributions in binary form must reproduce the above copyright
#notice, this list of conditions and the following disclaimer in the
#documentation and/or other materials provided with the distribution.
#* Neither the name of the <ORGANIZATION> nor the names of its contributors
#may be used to endorse or promote products derived from this software
#without specific prior written permission.

#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
#EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
#OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
#SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
#OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# WARNING : this program does not use any "one-way only" information, so paths using such lines may be wrong
#    e.g. : line 7bis

use strict ;
use warnings ;

use Getopt::Std ;
use IO::File ;

use lib $ENV{'METRO_HOME'};
use Metro ;

my %options=() ;
getopts("l:s:t:hm:u:a:n:p:z:dvV", \%options) ;

if (defined($options{V}))
{
    print "$VERSION\n" ;
    exit 0 ;
}
if (defined($options{h}))
{
    printHelp() ;
    exit 0 ;
}

# Load DB file
if (not defined($ARGV[-1]))
{
    printHelp() ;
    exit 1 ;
}
my @linesPool = () ;
if (loadLines(\@linesPool, "$ARGV[-1]") != 0)
{
    print "Unable to open file $ARGV[-1].\n" ;
    exit 1 ;
}
if (@linesPool <= 0)
{
    print "No line can be loaded from file $ARGV[-1].\n" ;
    exit 1 ;
}

### Dump all known lines
#foreach my $tmpline (@linesPool)
#{
#  print $tmpline->{type} . ":" . $tmpline->{name} . "\n" ;
#  foreach my $tmp (@{$tmpline->{stations}})
#  {
#    print $tmp . ":" ;
#  }
#  print "\n" ;
#  foreach my $tmp (@{$tmpline->{timing}})
#  {
#    print $tmp . ":" ;
#  }
#  print "\n" ;
#  foreach my $tmp (@{$tmpline->{zones}})
#  {
#    print $tmp . ":" ;
#  }
#  print "\n\n" ;
#}
#exit 0;
####

if (defined($options{l}))
{
    my @suggestedStationNames = grepStationName(\@linesPool, $options{l}, 1) ;
    if (@suggestedStationNames != 0)
    {
        print 'Found ' . @suggestedStationNames . ' station' . ((@suggestedStationNames > 1) ? 's' : '') . " :\n" ;
        for (my $i = 0 ; defined($suggestedStationNames[$i]) ; $i++)
        {
            print "\"$suggestedStationNames[$i]\"\n" ;
        }
        exit 0 ;
    }
    else
    {
        print "No station found.\n";
        exit 1 ;
    }
}

if ((not defined($options{s})) or (not defined($options{t})))
{
    printHelp() ;
}
else
{
    # Defaults
    if (not defined($options{u})) { $options{u} = 0 ; }
    if (not defined($options{a})) { $options{a} = 0 ; }
    if (not defined($options{m})) { $options{m} = 0 ; }
    if (not defined($options{n})) { $options{n} = 2 ; }
    if (not defined($options{p})) { $options{p} = 4 ; }
    if (not defined($options{z})) { $options{z} = 'd' ; }
    if (not defined($options{d})) { $options{d} = 0 ; }
    if (not defined($options{v})) { $options{v} = 0 ; }
    if(($options{z} ne 'u') and ($options{z} ne 'a') and ($options{z} ne 'd') and ($options{z} ne 'c') and ($options{z} ne 'z'))
    {
        print "Unknown sort option : $options{z}.\n" ;
        exit 1 ;
    }

    if (findLines($options{s}, \@linesPool) == 0)
    {
        print "Start station not found.\n" ;

        my @suggestedStationNames = grepStationName(\@linesPool, $options{s}, 1) ;
        if (@suggestedStationNames != 0)
        {
            print "(did you mean \"$suggestedStationNames[0]\" ?)\n" ;
        }

        exit 1 ;
    }
    elsif (findLines($options{t}, \@linesPool) == 0)
    {
        print "Stop station not found.\n" ;

        my @suggestedStationNames = grepStationName(\@linesPool, $options{t}, 1) ;
        if (@suggestedStationNames != 0)
        {
            print "(did you mean \"$suggestedStationNames[0]\" ?)\n" ;
        }

        exit 1 ;
    }

    print "Computing paths from $options{s} to $options{t} with a maximum of $options{n} changes. Please wait...\n" ;
    my @foundPaths = findPaths($options{s}, $options{t}, \@linesPool, $options{n}) ;
    computePaths(\@foundPaths) ;
    if (@foundPaths == 0)
    {
        print "No result found.\n" ;
        exit 1 ;
    }
    filterAndSortPaths(\@foundPaths, $options{m}, $options{u}, $options{a}, $options{p}, $options{z}, $options{d}) ;
    if (@foundPaths == 0)
    {
        print "No result found. Try -d or modify your filters.\n" ;
        exit 1 ;
    }
    else
    {
        print "\n" ;
        printResults(\@foundPaths, $options{v}) ;
        exit 0 ;
    }
}

exit 1 ;

