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
#    e.g. : line 7bis (Paris)

package Metro ;
require Exporter ;

use strict ;
use warnings ;

use Getopt::Std ;
use IO::File ;

our @ISA = qw(Exporter) ;
our @EXPORT = qw($VERSION printHelp loadLines grepStationName findLines findPaths computePaths filterAndSortPaths printResults) ;
our @EXPORT_OK = qw() ;
our $VERSION = 0.2 ;

# Loads lines reading a CSV file
# 1st arg = linesPool reference, 2nd arg = file name
# returns 0
sub loadLines($$)
{
    my ($linesPoolRef, $fileName) = @_ ;

    my $inputFile = IO::File->new() ;
    if (not $inputFile->open("<$fileName"))
    {
        return 1 ;
    }
    while (<$inputFile>)
    {
        chomp ;
        if (/^\s*line\s*=\s*([^:]*?):([^:]*?)\s*$/)
        {
            my %tmpLine = () ;
            $tmpLine{type} = $1 ;
            $tmpLine{name} = $2 ;
            $tmpLine{stations} = [] ;
            $tmpLine{timing} = [] ;
            $tmpLine{zones} = [] ;

            while (<$inputFile>)
            {
                chomp ;
                if (/^\s*stations\s*=\s*(.*?)\s*$/) { @{$tmpLine{stations}} = split(/:/, "$1") ; }
                elsif (/^\s*timing\s*=\s*(.*?)\s*$/) { @{$tmpLine{timing}} = split(/:/, "$1") ; }
                elsif (/^\s*zones\s*=\s*(.*?)\s*$/) { @{$tmpLine{zones}} = split(/:/, "$1") ; }
                elsif (/^\s*$/) { last ; }
            }

            if(($tmpLine{type} ne '') and ($tmpLine{name} ne '') and (@{$tmpLine{stations}} != 0) and (@{$tmpLine{timing}} != 0) and (@{$tmpLine{zones}} != 0))
            {
                push(@{$linesPoolRef}, \%tmpLine) ;
            }
            else
            {
                print "Warning : ignoring imcomplete line (" . $tmpLine{type} . ") from file $fileName.\n" ;
            }
        }
    }
    $inputFile->close();

    return 0 ;
}

# Performs a "uniq" on an array and returns the "uniqed" one
# 1st arg = array reference
# returns the "uniqed" array
sub uniq($)
{
    my ($arrayRef) = @_ ;

    my @seen = () ;
    my @uniq = () ;
    foreach my $item (@$arrayRef) {
        if (not grep(/$item/, @uniq)) { push(@uniq, $item) ; }
    }
    return @uniq ;
}

# Grep a line name in an array of line references
# 1st arg = array reference, 2nd arg = reference
# returns 1 if found, 0 if not found
sub grepLineName($$)
{
    my ($lineArrayRef, $lineRef) = @_ ;

    my $return = 0 ;
    for (my $i = 0 ; defined($lineArrayRef->[$i]) ; $i++)
    {
        if($lineArrayRef->[$i]->{name} == $lineRef->{name}) { $return++ ; }
    } 
    return $return ;
}

# Grep a station name in an array of line references
# 1st arg = array reference, 2nd arg = reference
# returns 1 if found, 0 if not found
sub grepStationName($$$)
{
    my ($lineArrayRef, $stationName, $avgMatch) = @_ ; 
    my $neutralStationName = $stationName ;

    my @return = () ;

    if ($avgMatch) { $neutralStationName =~ y/אהגיטכךןמצפשüûÿ/aaaeeeeiioouuuy/ } ;

    for (my $i = 0 ; defined($lineArrayRef->[$i]) ; $i++)
    {
        for (my $j = 0 ; defined($lineArrayRef->[$i]->{stations}->[$j]) ; $j++)
        {
            my $currentStationName = $lineArrayRef->[$i]->{stations}->[$j] ;
            if ($avgMatch) { $currentStationName =~ y/אהגיטכךןמצפשüûÿ/aaaeeeeiioouuuy/ } ;

            if(($currentStationName =~ /$neutralStationName/) or ($avgMatch and ($currentStationName =~ /$neutralStationName/i)))
            {
                push(@return, $lineArrayRef->[$i]->{stations}->[$j]) ;
            }
        }
    } 

    @return = uniq(\@return) ;
    @return = sort(@return) ;
    return @return ;
}

# Finds the next station on a line
# 1st arg = station name, 2nd argument = line ref
# returns a station name of the same line
sub nextStation($$)
{
        my ($stationName, $lineRef) = @_ ;
        for (my $i = 0 ; $lineRef->{stations}->[$i] ; $i++)
        {
                if ($lineRef->{stations}->[$i] eq $stationName)
                {
                        if ($lineRef->{stations}->[$i + 1]) { return $lineRef->{stations}->[$i + 1] ; }
                        else { return '' ; }
                }
        }
        return '' ;
}

# Finds the previous station on a line
# 1st arg = station name, 2nd argument = line ref
# returns a station name of the same line
sub previousStation($$)
{
        my ($stationName, $lineRef) = @_ ;
        # Start from 1 to avoid returning the last station
        for (my $i = 1 ; $lineRef->{stations}->[$i] ; $i++) 
        {
                if ($lineRef->{stations}->[$i] eq $stationName)
                {
                        if ($lineRef->{stations}->[$i - 1]) { return $lineRef->{stations}->[$i - 1] ; }
                        else { return '' ; }
                }
        }
        return '' ;
}

# Finds every lines a stations belongs to
# 1rst arg = station name, 2nd argument = lines array ref
# returns an array of line refs
sub findLines($$)
{
        my ($stationName, $linesRef) = @_ ;
        my @return = () ;
        for (my $i = 0 ; $linesRef->[$i] ; $i++)
        {
                for (my $j = 0 ; $linesRef->[$i]->{"stations"}->[$j] ; $j++)
                {
                        if ($linesRef->[$i]->{"stations"}->[$j] eq $stationName)
                        {
                            push(@return, $linesRef->[$i]) ;
                        }
                }
        }
        return @return ;
}

# Finds every common lines between two stations
# 1rst arg = 1st station name, 2nd arg = 2nd station name, 3rd argument = lines array ref
# returns an array of line refs
sub findCommonLines($$$)
{
    my ($station1, $station2, $linesRef) = @_ ;
    my @return = () ;

    my @lines1 = findLines($station1, $linesRef) ;
    my @lines2 = findLines($station2, $linesRef) ;
    foreach my $firstline (@lines1)
    {
        foreach my $secondline (@lines2)
        {
            if ($firstline->{"name"} eq $secondline->{"name"}) { push(@return, $firstline) ; }
        }
    }
    return @return ;
}

# Computes the duration of a travel between two stations on the same line
# 1st arg = start station, 2nd arg = stop station, 3rd arg = line ref
# returns a scalar (number)
sub computeDuration($$$)
{
    my ($startStation, $stopStation, $lineRef) = @_ ;
    my $return = 0 ;
    my $i = 0 ;

    # Find any of the 2 stations
    while (defined($lineRef->{stations}->[$i]) and ($lineRef->{stations}->[$i] ne $startStation) and ($lineRef->{stations}->[$i] ne $stopStation)) { $i++ ; }
    if (not defined($lineRef->{stations}->[$i])) { return 0 ; } # Station not found

    $return += $lineRef->{timing}->[$i] ;
    $i++ ;
    # Start from the next station found and compute duration
    while (defined($lineRef->{stations}->[$i]) and ($lineRef->{stations}->[$i] ne $startStation) and ($lineRef->{stations}->[$i] ne $stopStation))
    {
        $return += $lineRef->{timing}->[$i] ; 
        $i++ ;
    }
    if (not defined($lineRef->{stations}->[$i])) { return 0 ; } # Station not found

    return $return ;
}

# Returns the zone of a given station on a given line
# 1st arg = station name, 2nd arg = line reference
sub findZone($$)
{
    my ($stationName, $lineRef) = @_ ;
    for (my $i = 0 ; $lineRef->{stations}->[$i] ; $i++)
    {
            if ($lineRef->{stations}->[$i] eq $stationName)
            {
                    return $lineRef->{zones}->[$i] ;
            }
    }
    return 0 ;
}

# Recurse and find path to destination
# Not to be called directly (use findPaths instead)
# 1st declaration Mandatory because of the recursivity
sub crawlPaths($$$$$$$) ;
# 1st arg = start station name, 2nd argument = stop station name
# 3rd arg = lines pool array ref
# 4th arg = current path array ref, 5th arg = results pool array ref
# 6th arg = current number of line changes, 7th arg = max number of line changes
sub crawlPaths($$$$$$$)
{
        my ($startStation, $stopStation, $linesRef, $currentPathRef, $foundPathsRef, $currentChanges, $maxChanges) = @_ ;

        # If wrong arguments or station already passed or too many changes
        if (($startStation eq '') or ($stopStation eq '') or ($currentChanges > $maxChanges) or (grep(/^$startStation$/, @{$currentPathRef->{stations}})))
        {
            return 0 ;
        }
        # Path found
        elsif ($startStation eq $stopStation)
        {
            # Back-up the station in the current path
            push(@{$currentPathRef->{stations}}, $startStation) ;
            # Back-up the whole path (a new path is found)
            push(@$foundPathsRef, $currentPathRef) ;
            return 0 ;
        }
        else
        {
                # Backup-up the station in the current path
                push(@{$currentPathRef->{stations}}, $startStation) ;

                my @lines = findLines($startStation, $linesRef) ;
                # For each line containing the station
                for (my $i = 0 ; $lines[$i] ; $i++)
                {
                        # Find new path starting from the previous and the next station on the line
                        foreach my $station (previousStation($startStation, $lines[$i]), nextStation($startStation, $lines[$i]))
                        {
                                if ($station ne '') # If a station is found
                                {
                                    # Create a new path using the current one - copy to follow inner references
                                    my %newPath = (stations => [], lines => []) ;
                                    @{$newPath{stations}} = @{$currentPathRef->{stations}} ;
                                    @{$newPath{lines}} = @{$currentPathRef->{lines}} ;

                                    # Back-up the next Line reference
                                    push(@{$newPath{lines}}, $lines[$i]) ;

                                    # Is the station on another line ?
                                    if ($currentPathRef->{lines}->[-1] and ($currentPathRef->{lines}->[-1]->{name} ne $lines[$i]->{name}))
                                    {
                                        crawlPaths($station, $stopStation, $linesRef, \%newPath, $foundPathsRef, $currentChanges+1, $maxChanges) ;
                                    }
                                    else
                                    {
                                        crawlPaths($station, $stopStation, $linesRef, \%newPath, $foundPathsRef, $currentChanges, $maxChanges) ;
                                    }
                                }
                        }
                }
        }
        return 0 ;
}

# Frontend to crawlPaths - designed to launch as many crawls as existing lines for the first Station
# 1st arg = start station name, 2nd argument = stop station name
# 3rd arg = lines pool array ref, 4th arg = max line changes
# returns an array of paths (stations => [], lines => []) hashes
sub findPaths($$$$)
{
        my ($startStation, $stopStation, $linesRef, $maxChanges) = @_ ;
        my @foundPaths = () ;
        my $changes = 0 ;
        my @startLines = findLines($startStation, $linesRef) ;

        # For each line containing the station, start a crawl (useful to know the first station's line)
        for (my $i = 0 ; $startLines[$i] ; $i++)
        {
                my %currentPath = (stations => [], lines => []) ;

                # Back-up the next Line reference
                push(@{$currentPath{lines}}, $startLines[$i]) ;

                crawlPaths($startStation, $stopStation, $linesRef, \%currentPath, \@foundPaths, $changes, $maxChanges) ;
        }

        return @foundPaths ;
}

# Analyzes found paths and adds metadata information : duration, numChanges, minZone, maxZone, globalLines
# 1st arg = paths array reference
# returns 0
sub computePaths($)
{
        my ($foundPathsRef) = @_ ;

        for (my $i = 0 ; $foundPathsRef->[$i] ; $i++)
        {
            my $path = $foundPathsRef->[$i] ;

            $path->{duration} = 0 ;
            $path->{numChanges} = 0 ;
            $path->{minZone} = 1 ;
            $path->{maxZone} = 1 ;
            $path->{globalLines} = [] ;

            for (my $j = 0 ; $path->{stations}->[$j] ; $j++)
            {
                if ((not defined $path->{globalLines}->[0]) or ($path->{globalLines}->[-1]->{name} ne $path->{lines}->[$j]->{name})) # globalLines
                {
                    push(@{$path->{globalLines}}, $path->{lines}->[$j]) ;
                }

                if (defined($path->{stations}->[$j+1])) # not the last station
                {
                    $path->{duration} += computeDuration($path->{stations}->[$j], $path->{stations}->[$j+1], $path->{lines}->[$j+1]) ; # duration
                    if ($path->{lines}->[$j]->{name} ne $path->{lines}->[$j+1]->{name}) # numChanges
                    {
                        $path->{numChanges}++ ;
                    }
                }
                my $tmpZone = findZone($path->{stations}->[$j], $path->{lines}->[$j]) ;
                $path->{minZone} = $path->{minZone} < $tmpZone ? $path->{minZone} : $tmpZone ; # minZone
                $path->{maxZone} = $path->{maxZone} > $tmpZone ? $path->{maxZone} : $tmpZone ; # maxZone
            }
        }
        return 0 ;
}

# Filter and sort found paths given parameters
# 1st arg = paths array reference, 2nd arg = 
# returns a new filtered/sorted array
sub filterAndSortPaths($$$$$$$)
{
    my ($foundPathsRef, $option_m, $option_u, $option_a, $option_p, $option_z, $option_d) = @_ ;

    my $i = 0 ;
    while (defined($foundPathsRef->[$i]))
    {
        # Manage -m (maximum zone allowed)
        if (($option_m != 0) and ($foundPathsRef->[$i]->{maxZone} > $option_m))
        {
            splice(@{$foundPathsRef}, $i, 1) ;
            next ;
        }
        # Manage -u (maximum duration allowed)
        if (($option_u != 0) and ($foundPathsRef->[$i]->{duration} > $option_u))
        {
            splice(@{$foundPathsRef}, $i, 1) ;
            next ;
        }
        # Manage -a (maximum number of stations allowed)
        if (($option_a != 0) and (@{$foundPathsRef->[$i]->{stations}} > $option_a))
        {
            splice(@{$foundPathsRef}, $i, 1) ;
            next ;
        }
        # Manage -d (dummy mode), check lines (at least 2 stations to make a valid path)
        if ($option_d == 0) # Have to filter
        {
            if (not defined($foundPathsRef->[$i]->{lines}->[0]) or not defined($foundPathsRef->[$i]->{lines}->[1]) or ($foundPathsRef->[$i]->{lines}->[0]->{name} ne $foundPathsRef->[$i]->{lines}->[1]->{name})) # pb with 1st or second station, or change at first station
            {
                splice(@{$foundPathsRef}, $i, 1) ;
                next ;
            }

            # look for twice the same line in the path
            my $j = 0 ;
            while (defined($foundPathsRef->[$i]->{lines}->[$j]) and (grepLineName($foundPathsRef->[$i]->{globalLines}, $foundPathsRef->[$i]->{lines}->[$j]) <= 1)) { $j++ ; }
            if (defined($foundPathsRef->[$i]->{lines}->[$j]))
            {
                splice(@{$foundPathsRef}, $i, 1) ;
                next ;
            }
        }

        $i++ ;
    }

    # Manage -z (sort entries)
    if ($option_z ne 'u')
    {
        if ($option_z eq 'a') # by stations
        {
            my @foundPaths = sort { @{$a->{stations}} <=> @{$b->{stations}} } @{$foundPathsRef} ;
            @{$foundPathsRef} = @foundPaths ;
        }
        elsif ($option_z eq 'd') # by duration
        {
            my @foundPaths = sort { $a->{duration} <=> $b->{duration} } @{$foundPathsRef} ;
            @{$foundPathsRef} = @foundPaths ;
        }
        elsif ($option_z eq 'c') # by changes
        {
            my @foundPaths = sort { $a->{numChanges} <=> $b->{numChanges} } @{$foundPathsRef} ;
            @{$foundPathsRef} = @foundPaths ;
        }
        elsif ($option_z eq 'z') # by max zone
        {
            my @foundPaths = sort { $a->{maxZone} <=> $b->{maxZone} } @{$foundPathsRef} ;
            @{$foundPathsRef} = @foundPaths ;
        }
    }

    # Manage -p (truncate results)
    if ($option_p > 0 and ($option_p < @{$foundPathsRef}))
    {
        splice(@{$foundPathsRef}, $option_p) ;
    }

    return 0 ;
}

# Prints the paths found
# 1st arg = paths array reference, 2nd arg = number of results to print
sub printResults($$)
{
        my ($foundPathsRef, $option_v) = @_ ;

        for (my $i = 0 ; $foundPathsRef->[$i] ; $i++)
        {
            my $path = $foundPathsRef->[$i] ;

            # Print path information
            if ($option_v)
            {
                print "[Path " . ($i + 1) . "]\n" ;
                print "Total duration : " . $foundPathsRef->[$i]->{duration} . "min\n" ;
                print "Total stations : " . @{$foundPathsRef->[$i]->{stations}} . "\n" ;
                print "Lines          : " ;
                for (my $j = 0 ; $path->{globalLines}->[$j] ; $j++)
                {
                    if (not $path->{globalLines}->[$j+1])
                    {
                        print $path->{globalLines}->[$j]->{type} . $path->{globalLines}->[$j]->{name} . "\n" ;
                    }
                    else
                    {
                        print $path->{globalLines}->[$j]->{type} . $path->{globalLines}->[$j]->{name} . ", " ;
                    }
                }
                print "Changes        : " . $foundPathsRef->[$i]->{numChanges} . "\n" ;
                print "MinZone        : " . $foundPathsRef->[$i]->{minZone} . "\n" ;
                print "MaxZone        : " . $foundPathsRef->[$i]->{maxZone} . "\n" ;
                print "Detail         : " ;
            }
            # Print path
            for (my $j = 0 ; $path->{stations}->[$j] ; $j++)
            {
                if (not $path->{lines}->[$j+1]->{name}) # last station
                {
                    print "(" . $path->{lines}->[$j]->{type} . $path->{lines}->[$j]->{name} . ")" . $path->{stations}->[$j] . "\n\n" ;
                }
                elsif ($path->{lines}->[$j]->{name} eq $path->{lines}->[$j+1]->{name}) # next station on the same line
                {
                    print "(" . $path->{lines}->[$j]->{type} . $path->{lines}->[$j]->{name} . ")" . $path->{stations}->[$j] ;
                    print ", " ;
                }
                else # line change
                {
                    print "(" . $path->{lines}->[$j]->{type} . $path->{lines}->[$j]->{name} . "->" . $path->{lines}->[$j+1]->{type} . $path->{lines}->[$j+1]->{name} . ")" . $path->{stations}->[$j] ;
                    print ", " ;
                }
            }
        }
        return 0 ;
}

sub printHelp()
{
    print "Usage: metro -s <start> -t <stop> [-n <n>] [-u <n>] [-a <n>] [-m <n>] [-z <d|c|z|u>] [-d] [-p <n>] [-v] <filename.db>\n" ;
    print "       metro -l <station> <filename.db>\n" ;
    print "Lookup options :\n" ;
    print "\t-s : start station (e.g. Nation)\n" ;
    print "\t-t : stop Station (e.g. Pasteur)\n" ;
    print "\t-n : maximum number of changes (default : 2)\n" ;
    print "\t-l : lookup station (e.g. Nation)\n" ;
    print "Filter options :\n" ;
    print "\t-u : maximum duration (min) allowed for paths (default : 0, unlimited)\n" ;
    print "\t-a : maximum number of stations allowed for paths (default : 0, unlimited)\n" ;
    print "\t-m : maximum zone allowed for paths (default : 0, unlimited)\n" ;
    print "\t-z : sort results by (d)uration, st(a)tions, (c)hanges or max (z)one or leave them (u)nsorted (default : d)\n" ;
    print "\t-d : dummy mode (show line changes at first station, single-station paths, and twice-the-same-line paths)\n" ;
    print "Display options :\n" ;
    print "\t-p : number of answers to show (default : 4, 0 = unlimited)\n" ;
    print "\t-v : verbose mode (print paths information)\n" ;
    print "Other options :\n" ;
    print "\t-h : help\n" ;
    print "\t-V : print version\n" ;
    print "E.g. : metro -s Nation -t Pasteur paris-metro.db\n" ;
    return 0 ;
}

1 ;

