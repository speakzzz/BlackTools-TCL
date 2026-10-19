#!/usr/bin/env tclsh
#################################################################
# BlackTools translation checker
#
# Compares every language file with the English one and lists:
#   - messages that exist in English but are missing in a translation
#     (the bot errors out instead of replying when it needs one of these)
#   - messages a translation has but English doesn't (old or misspelled names)
#   - messages filed under the wrong language name (say.en.* in the French file)
#   - names that aren't of the form say.<lang>.<name> (typos such as sayen.x)
#   - messages set twice in the same file (only the last one is used)
#   - translations that leave out a %placeholder% the English text uses, or
#     use one the bot doesn't fill in for that message
#
# It only reads the files; nothing is changed and the bot doesn't need to run.
#
# Usage (from a shell, not from IRC):
#   tclsh BlackTools/tools/langcheck.tcl            check every language
#   tclsh BlackTools/tools/langcheck.tcl fr         check only French
#   tclsh BlackTools/tools/langcheck.tcl -v fr      also print the English text
#   tclsh BlackTools/tools/langcheck.tcl -dir PATH  BlackTools folder elsewhere
#
# Exit status: 0 when nothing is missing, 1 when something is missing,
# 2 when a file can't be read.
#################################################################

set verbose 0
set only {}
set base [file normalize [file join [file dirname [info script]] ..]]

for {set i 0} {$i < [llength $argv]} {incr i} {
	set a [lindex $argv $i]
	switch -- $a {
		-v - --verbose { set verbose 1 }
		-dir {
			incr i
			set base [file normalize [lindex $argv $i]]
		}
		-h - --help {
			puts "usage: tclsh [info script] ?-v? ?-dir BlackToolsFolder? ?lang ...?"
			exit 0
		}
		default { lappend only [string tolower $a] }
	}
}

set langdir [file join $base lang]
if {![file isdirectory $langdir]} {
	puts stderr "Can't find the language folder: $langdir"
	puts stderr "Run this from the folder that has BlackTools.tcl, or pass -dir path/to/BlackTools"
	exit 2
}

# Read one file in a separate interpreter so nothing in it can touch this one.
# Returns a dict of name -> text for every black() entry it sets.
proc load_file {path} {
	set i [interp create -safe]
	$i eval {
		proc unknown args { return "" }
		array set black {}
		# Some texts include settings such as $black(vers); give any setting
		# that isn't defined here an empty value so the file still loads.
		proc fill {name1 name2 op} {
			upvar 1 $name1 arr
			if {$name2 ne "" && ![info exists arr($name2)]} { set arr($name2) "" }
		}
		trace add variable black read fill
	}
	set fh [open $path r]
	fconfigure $fh -encoding binary -translation auto
	set code [read $fh]
	close $fh
	# Names set more than once in this file, with their line numbers
	set seen [dict create]
	set n 0
	foreach line [split $code \n] {
		incr n
		if {[regexp {^\s*set\s+black\(([^)\s]+)\)} $line - name]} { dict lappend seen $name $n }
	}
	set ::dups($path) {}
	dict for {name lines} $seen {
		if {[llength $lines] > 1} { lappend ::dups($path) [list $name $lines] }
	}
	if {[catch {$i eval $code} err]} {
		interp delete $i
		return -code error $err
	}
	set out [dict create]
	foreach name [$i eval {array names black}] {
		# entries the trace above created while reading aren't messages
		if {[$i eval [list set black($name)]] eq "" && ![regexp {^say} $name]} continue
		dict set out $name [$i eval [list set black($name)]]
	}
	interp delete $i
	return $out
}

# Split "say.fr.idle.27" into {fr idle.27}; anything else gives {"" name}
proc split_key {key} {
	if {[regexp {^say\.([a-z]{2})\.(.+)$} $key - l rest]} { return [list $l $rest] }
	return [list "" $key]
}

# Placeholders the bot fills in for every message, so a translation may use
# them even where the English text doesn't
set common_ph {botnick chan char firstchar bind}

# Every %name% used in a message (lists of random lines are checked as a whole)
proc placeholders {text} {
	set found {}
	foreach {- p} [regexp -all -inline {%([A-Za-z0-9_.]+)%} $text] {
		if {[lsearch -exact $found $p] < 0} { lappend found $p }
	}
	return [lsort $found]
}

proc short {text} {
	regsub -all {[\x00-\x1f]} $text "" text
	regsub -all {\s+} $text " " text
	set text [string trim $text]
	if {[string length $text] > 90} { set text "[string range $text 0 86]..." }
	return $text
}

proc show_dups {path} {
	if {![llength $::dups($path)]} return
	puts "   set more than once, only the last is used ([llength $::dups($path)]):"
	foreach d [lsort -dictionary -index 0 $::dups($path)] {
		lassign $d name lines
		puts "     black($name) on lines [join $lines {, }]"
	}
}

# Collect the files: kind "messages" is BT.xx.lang.tcl, kind "manual" is BT.man-xx.lang.tcl
set files [dict create]
foreach path [lsort [glob -nocomplain -directory $langdir BT.*.lang.tcl]] {
	set name [file tail $path]
	if {[regexp {^BT\.man-([a-z]{2})\.lang\.tcl$} $name - l]} {
		dict set files manual $l $path
	} elseif {[regexp {^BT\.([a-z]{2})\.lang\.tcl$} $name - l]} {
		dict set files messages $l $path
	}
}

set status 0
set total_missing 0

foreach kind {messages manual} {
	if {![dict exists $files $kind en]} {
		puts stderr "No English $kind file in $langdir"
		set status 2
		continue
	}
	if {[catch {load_file [dict get $files $kind en]} ref]} {
		puts stderr "Couldn't read [file tail [dict get $files $kind en]]: $ref"
		set status 2
		continue
	}
	# English keys without the "say.en." part
	set eng [dict create]
	set enbad {}
	dict for {k v} $ref {
		lassign [split_key $k] l rest
		if {$l eq "en"} { dict set eng $rest $v } else { lappend enbad $k }
	}
	# Problems in the English file itself
	set enpath [dict get $files $kind en]
	if {[llength $enbad] || [llength $::dups($enpath)]} {
		puts "== [file tail $enpath] (English, $kind)"
		if {[llength $enbad]} {
			puts "   misspelled names ([llength $enbad]):"
			foreach b [lsort -dictionary $enbad] { puts "     black($b)" }
		}
		show_dups $enpath
	}

	foreach l [lsort [dict keys [dict get $files $kind]]] {
		if {$l eq "en"} continue
		if {[llength $only] && [lsearch -exact $only $l] < 0} continue
		set path [dict get $files $kind $l]
		set fname [file tail $path]
		if {[catch {load_file $path} data]} {
			puts "== $fname: can't be read: $data"
			set status 2
			continue
		}
		set have [dict create]
		set wrong {}
		set bad {}
		dict for {k v} $data {
			lassign [split_key $k] kl rest
			if {$kl eq $l} {
				dict set have $rest $v
			} elseif {$kl eq ""} {
				lappend bad $k
			} else {
				lappend wrong $k
			}
		}
		set missing {}
		set extra {}
		set ph {}
		dict for {rest v} $eng {
			if {![dict exists $have $rest]} {
				lappend missing $rest
			} else {
				set pe [placeholders $v]
				set pt [placeholders [dict get $have $rest]]
				set lost {}
				set added {}
				foreach x $pe { if {[lsearch -exact $pt $x] < 0} { lappend lost %$x% } }
				foreach x $pt {
					if {[lsearch -exact $pe $x] < 0 && [lsearch -exact $::common_ph $x] < 0} { lappend added %$x% }
				}
				if {[llength $lost] || [llength $added]} { lappend ph [list $rest $lost $added] }
			}
		}
		dict for {rest v} $have {
			if {![dict exists $eng $rest]} { lappend extra $rest }
		}
		set missing [lsort -dictionary $missing]
		set extra [lsort -dictionary $extra]
		set ph [lsort -dictionary -index 0 $ph]
		incr total_missing [llength $missing]

		puts "== $fname ($kind, [dict size $have] of [dict size $eng] English messages)"
		if {![llength $missing] && ![llength $extra] && ![llength $wrong] && ![llength $bad] && ![llength $ph] && ![llength $::dups($path)]} {
			puts "   ok"
			continue
		}
		if {[llength $missing]} {
			puts "   missing ([llength $missing]):"
			foreach m $missing {
				if {$verbose} {
					puts "     say.$l.$m   EN: [short [dict get $eng $m]]"
				} else {
					puts "     say.$l.$m"
				}
			}
		}
		if {[llength $bad]} {
			puts "   misspelled names ([llength $bad]):"
			foreach b [lsort -dictionary $bad] { puts "     black($b)" }
		}
		show_dups $path
		if {[llength $wrong]} {
			puts "   filed under another language ([llength $wrong]):"
			foreach w [lsort -dictionary $wrong] { puts "     $w" }
		}
		if {[llength $extra]} {
			puts "   not in English ([llength $extra]):"
			foreach e $extra { puts "     say.$l.$e" }
		}
		if {[llength $ph]} {
			puts "   placeholders differ ([llength $ph]):"
			foreach p $ph {
				lassign $p rest lost added
				set why {}
				if {[llength $lost]} { lappend why "lacks [join $lost {, }]" }
				if {[llength $added]} { lappend why "adds [join $added {, }]" }
				puts "     say.$l.$rest: [join $why {; }]"
			}
		}
	}
}

if {$status == 0 && $total_missing > 0} { set status 1 }
if {$status != 2} {
	if {$total_missing} {
		puts "\n$total_missing missing message(s) in total."
	} else {
		puts "\nNo missing messages."
	}
}
exit $status
