#########################################################################
##          BlackTools - The Ultimate Channel Control Script           ##
##                    One TCL. One smart Eggdrop                       ##
#########################################################################
############################   HISTORY TCL   ############################
#########################################################################
##                                                                     ##
##   Fork addition (speakzzz, 2026)                                    ##
##                                                                     ##
##   Records who changed users and settings, and when, so a channel   ##
##   with several managers can see what happened.                      ##
##                                                                     ##
##   !history [#chan] [number]   changes on a channel (MANAGER+)       ##
##   !history global [number]    global changes (BOSS, OWNER, MASTER)  ##
##                                                                     ##
##   Nothing is recorded by the commands themselves: when the bot      ##
##   sends one of the confirmation messages below (user added, access ##
##   removed, setting changed...), blacktools:tell passes it here.     ##
##   An entry keeps the message name and its details, so !history     ##
##   shows it in the language of whoever reads it.                     ##
##                                                                     ##
#########################################################################

set black(history_file) "$black(backdir)/BlackTools/FILES/$username.history.txt"
if {![info exists black(history:max)]} { set black(history:max) 1000 }

#Confirmation messages recorded under the channel they happened on
set black(history:chankeys) {
	add.19 delacc.1 s.2 us.2
	auto.10 auto.11 auto.18 auto.19
	set.6 set.8 unset.2 unset.4 unset.5
	enable.1 enable.4 disable.1 disable.4
}

#Confirmation messages for changes that aren't tied to one channel
set black(history:globalkeys) {
	add.10 add.20 del.1 delacc.2 delacc.4 chuser.1 addhost.2 delhost.2
	s.5 us.3 auto.12 auto.13 auto.20 auto.21
	set.1 addchan.3 delchan.3 suspend.4 unsuspend.4 enable.6 disable.6
}

set black(history:keys) [concat $black(history:chankeys) $black(history:globalkeys)]

###################### recording ######################

#Called from blacktools:tell for every message in black(history:keys)
proc blacktools:history:add {nick hand chan key arg} {
	global black
if {[lsearch -exact $black(history:globalkeys) $key] > -1} {
	set scope "*"
} else {
	set scope [string tolower $chan]
}
	set line [list [clock seconds] $scope $chan $hand $nick $key $arg]
	set f [open $black(history_file) a]
	fconfigure $f -encoding utf-8
	puts $f $line
	close $f
if {![info exists black(history:count)]} {
	set black(history:count) [llength [blacktools:history:read]]
} else {
	incr black(history:count)
}
	#keep the newest history:max entries; trim once 10% over so the file
	#isn't rewritten on every change
	set max $black(history:max)
if {$max > 0 && $black(history:count) > $max + $max / 10} {
	set lines [lrange [blacktools:history:read] end-[expr {$max - 1}] end]
	set tmp "$black(history_file).bt-tmp"
	set f [open $tmp w]
	fconfigure $f -encoding utf-8
	puts -nonewline $f [join $lines \n]\n
	close $f
	blacktools:replace_atomic $tmp $black(history_file)
	set black(history:count) [llength $lines]
	}
}

#All entries, oldest first. Lines that aren't a valid entry are skipped.
proc blacktools:history:read {} {
	global black
if {![file exists $black(history_file)]} { return {} }
	set f [open $black(history_file) r]
	fconfigure $f -encoding utf-8
	set data [read -nonewline $f]
	close $f
	set out {}
foreach line [split $data \n] {
if {[catch {llength $line} n] || $n != 7} { continue }
	lappend out $line
	}
	return $out
}

#The text of a recorded message in the reader's language, without the
#[BT] prefix
proc blacktools:history:render {hand chan key arg} {
	global black botnick
	set getlang ""
if {[validuser $hand]} {
	set getlang [string tolower [getuser $hand XTRA OUTPUT_LANG]]
}
if {$getlang == ""} { set getlang [string tolower $black(default_lang)] }
if {![info exists black(say.$getlang.$key)]} { set getlang "en" }
if {![info exists black(say.$getlang.$key)]} { return "$key $arg" }
	set tpl $black(say.$getlang.$key)
	set prefix "\005\[BT\]\005"
if {[string first $prefix $tpl] == 0} {
	set tpl [string trimleft [string range $tpl [string length $prefix] end]]
}
	set text [join [black:color:set $hand $tpl]]
	array set replace [blacktools:msg_map $arg]
	set replace(%chan%) $chan
	set replace(%botnick%) $botnick
	set replace(%char%) [lindex $black(cmdchar) 0]
	set replace(%firstchar%) [lindex $black(cmdchar) 0]
	set replace(%bind%) ""
	set reply [string map [array get replace] $text]
	return [string map [list {\"} \" {\[} \[ {\]} \] {\?} \? {\\} \\] $reply]
}

###################### !history ######################

proc history:process {nick host hand chan chan1 args_text type} {
	global black
if {[matchattr $hand q]} { blacktools:tell $nick $host $hand $chan $chan1 gl.glsuspend none
	return
}
if {[matchattr $hand -|q $chan]} { blacktools:tell $nick $host $hand $chan $chan1 gl.suspend none
	return
}
	set cmd_status [btcmd:status $chan $hand "history" 0]
if {$cmd_status == "1"} {
	return
}
	#!history [#chan|global] [number], in any order
	set global 0
	set count 10
	set target $chan
foreach w [split $args_text] {
if {$w == ""} { continue }
if {[string equal -nocase $w "global"]} {
	set global 1
} elseif {[regexp {^[&#]} $w]} {
	set target $w
} elseif {[string is digit -strict $w]} {
	set count $w
	}
}
if {$count < 1} { set count 1 }
if {$count > 30} { set count 30 }

if {$global} {
if {![matchattr $hand nmo]} {
	blacktools:tell $nick $host $hand $chan $chan1 history.6 none
	return
}
	set scope "*"
} else {
if {![validchan $target]} {
	blacktools:tell $nick $host $hand $target $chan1 gl.novalidchan none
	return
}
if {![matchattr $hand nmo|M $target]} {
	blacktools:tell $nick $host $hand $target $chan1 gl.noaccess none
	return
}
	set scope [string tolower $target]
}
	set found {}
foreach e [blacktools:history:read] {
if {[lindex $e 1] eq $scope} { lappend found $e }
}
if {![llength $found]} {
if {$global} {
	blacktools:tell $nick $host $hand $target $chan1 history.5 none
} else {
	blacktools:tell $nick $host $hand $target $chan1 history.3 none
}
	return
}
	set found [lrange $found end-[expr {$count - 1}] end]
if {$global} {
	blacktools:tell $nick $host $hand $target $chan1 history.4 [llength $found]
} else {
	blacktools:tell $nick $host $hand $target $chan1 history.1 [llength $found]
}
foreach e [lreverse $found] {
	lassign $e time scope echan ehand enick key earg
	set who $ehand
if {$who == "" || $who == "*"} { set who $enick }
	set when [clock format $time -format "%Y-%m-%d %H:%M"]
	set text [blacktools:history:render $hand $echan $key $earg]
	blacktools:tell $nick $host $hand $target $chan1 history.2 "$when $who $text"
	}
}

#########################################################################
##   END                                                               ##
#########################################################################
