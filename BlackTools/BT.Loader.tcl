#########################################################################
##          BlackTools - The Ultimate Channel Control Script           ##
##                    One TCL. One smart Eggdrop                       ##
#########################################################################
##########################   LOADER TCL   ###############################
#########################################################################
##						                       ##
##   BlackTools  : http://blacktools.tclscripts.net	               ##
##   Bugs report : http://www.tclscripts.net/	                       ##
##   GitHub page : https://github.com/tclscripts/BlackToolS-TCL        ##
##   Online Help : irc://irc.undernet.org/tcl-help 	               ##
##                 #TCL-HELP / UnderNet                                ##
##                 You can ask in english or romanian                  ##
##					                               ##
#########################################################################

if {[info exists black(backup_update)]} {
	set black(backdir) $black(backup_dir)
} else {
	set black(backdir) $black(dirname)
}

if {[info exists black(update_disabled)]} {
	unset black(update_disabled)
}

#Fork change (speakzzz, 2026): a module, command or protection file that
#fails to load is logged and skipped instead of killing the bot, so owners
#can still reach it (and run .update) to fix the problem. The core files
#below remain required.

set black(load_errors) [list]

#Short name from the path, e.g. ".../BT.backup/.../BT.Seen.tcl" -> "Seen"
proc blacktools:load_name {file} {
	return [regsub {^BT\.} [file rootname [file tail $file]] ""]
}

#Source a file at global level; on failure log it with the line number,
#record it in black(load_errors) and return 0.
proc blacktools:load_optional {kind file} {
	global black
	set name [blacktools:load_name $file]
if {![catch {uplevel #0 [list source $file]} err opts]} {
	return 1
}
	set where ""
if {[regexp {\(file "[^"]*" line (\d+)\)} [dict get $opts -errorinfo] -> line]} {
	set where " (line $line)"
}
	set err [string range [regsub -all {[\x00-\x1f]+} $err " "] 0 300]
	lappend black(load_errors) [list $kind $name "$err$where"]
	putlog "\[BT\] WARNING: couldn't load the $kind \"$name\" ([file tail $file])$where, skipping it. Reason: $err"
	return 0
}

#Load modules

foreach file [lsort [glob -nocomplain -directory "$black(backdir)/BlackTools/Modules/" "*.tcl"]] {
if {![blacktools:load_optional module $file]} {
if {[blacktools:load_name $file] eq "AutoUpdate"} {
	set black(update_disabled) [lindex $black(load_errors) end 2]
		}
	}
}

#Load cmds

foreach file [lsort [glob -nocomplain -directory "$black(backdir)/BlackTools/Commands/" "*.tcl"]] {
	blacktools:load_optional "commands file" $file
}

#Load protections

foreach file [lsort [glob -nocomplain -directory "$black(backdir)/BlackTools/Protections/" "*.tcl"]] {
	blacktools:load_optional protection $file
}

#Load script files

set black(timers_error) [catch {source $black(backdir)/BlackTools/BT.Timers.tcl} black(timers_error_stats)]
set black(binds_error) [catch {source $black(backdir)/BlackTools/BT.Binds.tcl} black(binds_error_stats)]
set black(ban_error) [catch {source $black(backdir)/BlackTools/BT.Ban.tcl} black(ban_error_stats)]
set black(core_error) [catch {source $black(backdir)/BlackTools/BT.Core.tcl} black(core_error_stats)]
set black(loader_error) [catch {source $black(backdir)/BlackTools/lang/loader.tcl} black(loader_error_stats)]

#Check for errors in script files
if {$black(timers_error) == "1"} {
	die "\[BT\] Error. Couldn't load the \"BT Timers\". Reason: \"$black(timers_error_stats)\""
}
if {$black(binds_error) == "1"} {
	die "\[BT\] Error. Couldn't load the \"BT Binds\". Reason: \"$black(binds_error_stats)\""
}
if {$black(core_error) == "1"} {
	die "\[BT\] Error. Couldn't load the \"BT Core\". Reason: \"$black(core_error_stats)\""
}
if {$black(ban_error) == "1"} {
	die "\[BT\] Error. Couldn't load the \"BT Ban\". Reason: \"$black(ban_error_stats)\""
}
if {$black(loader_error) == "1"} {
	die "\[BT\] Error. Couldn't load the \"BT Language\". Reason: \"$black(loader_error_stats)\""
}

if {[llength $black(load_errors)] > 0} {
	set failed [list]
foreach e $black(load_errors) { lappend failed "[lindex $e 1] ([lindex $e 0])" }
	putlog "\[BT\] Loaded with [llength $black(load_errors)] problem(s): [join $failed ", "]. The rest of BlackTools is running; fix or update the files above and .rehash."
}

#Fork change (speakzzz, 2026): owner notifications.
#Boss owners get a note when files were skipped at load or when the bot
#can't save its data, and another once the problem is gone. Checks run a
#minute after loading, because on startup eggdrop reads its user list after
#the scripts; the storage check also runs every hour. A problem is only
#marked as reported once an owner was actually reached, otherwise it is
#retried every 5 minutes (e.g. a new bot started with -m has no owners yet).

#Run cmd in secs seconds, replacing any pending run of the same cmd.
proc blacktools:schedule {secs cmd} {
foreach t [utimers] {
if {[lindex $t 1] eq [list catch $cmd]} { killutimer [lindex $t 2] }
}
	utimer $secs [list catch $cmd]
}

#Send lang message key (with %msg.1% = list) to every boss owner as a note.
#If the note can't be stored, owners who are online get a notice instead.
#Returns how many owners were handled (reached, or have notes turned off);
#0 means nobody got it and the caller should try again later.
proc blacktools:owner_notify {key list} {
	global black botnick
	set handled 0
foreach user [userlist n] {
if {[getuser $user XTRA NO_NOTES] ne ""} { incr handled ; continue }
	set lang [string tolower [getuser $user XTRA OUTPUT_LANG]]
if {$lang eq ""} { set lang [string tolower $black(default_lang)] }
if {![info exists black(say.$lang.$key)]} { set lang "en" }
if {![info exists black(say.$lang.$key)]} { continue }
	set text [black:color:set $botnick $black(say.$lang.$key)]
	set text [string map [list %msg.1% $list] $text]
if {[info procs notes:add] ne "" && ![catch {notes:add $botnick "" $user "DB" "INBOX" $text "BlackTools" 0}]} {
	set black(notes:announce:$user) 1
	incr handled
	continue
}
	set unick [hand2nick $user]
if {$unick ne ""} {
	putserv "NOTICE $unick :$text"
	incr handled
	}
}
	return $handled
}

#The last reported problem list. Memory is always current while the bot runs
#(even if the state file couldn't be written); the file covers restarts.
proc blacktools:state_get {name} {
	global black
if {[info exists black(state:$name)]} { return $black(state:$name) }
	set sf "$black(dirname)/BlackTools/FILES/$name.txt"
if {[file readable $sf] && ![catch {set fh [open $sf r]; set v [string trim [read $fh]]; close $fh}]} {
	return $v
}
	return ""
}

proc blacktools:state_set {name value} {
	global black
	set black(state:$name) $value
	catch {blacktools:write_atomic "$black(dirname)/BlackTools/FILES/$name.txt" $value}
}

#Returns 1 (and remembers it) the first time a problem list is seen, so each
#warning is logged once rather than on every retry or hourly check.
proc blacktools:first_time {name problems} {
	global black
if {[info exists black(logged:$name)] && $black(logged:$name) eq $problems} { return 0 }
	set black(logged:$name) $problems
	return 1
}

#Tell owners about files skipped at load (loader.1) or that all load again (loader.2)
proc blacktools:load_notify {} {
	global black
	set problems [list]
	set items [list]
foreach e $black(load_errors) {
	lassign $e kind name reason
	lappend problems "$kind:$name"
	lappend items "$name ($kind): [string range $reason 0 80]"
}
	set problems [lsort $problems]
	set previous [blacktools:state_get load_state]
if {$problems eq $previous} { return }
	set key [expr {$problems eq "" ? "loader.2" : "loader.1"}]
if {[blacktools:owner_notify $key [string range [join $items "; "] 0 350]] == 0} {
if {[blacktools:first_time load_wait $problems]} {
	putlog "\[BT\] No boss owner could be told about load problems yet, trying again every 5 minutes."
}
	blacktools:schedule 300 blacktools:load_notify
	return
}
	blacktools:state_set load_state $problems
}

#Folders the bot must be able to write to: {label path} pairs
proc blacktools:storage_dirs {} {
	global black userfile chanfile
	set dirs [list]
if {[info exists userfile] && $userfile ne ""} { lappend dirs "user file" [file dirname $userfile] }
if {[info exists chanfile] && $chanfile ne ""} { lappend dirs "channel file" [file dirname $chanfile] }
	lappend dirs "BlackTools data" "$black(dirname)/BlackTools/FILES"
	return $dirs
}

#A real test write: catches a missing folder, wrong permissions and a full disk.
#Returns "" if the folder is fine, otherwise the reason.
proc blacktools:storage_test {dir} {
if {![file isdirectory $dir]} { return "folder does not exist" }
	set t [file join $dir ".bt-write-test"]
if {[catch {set f [open $t w]; puts $f "BlackTools write test"; close $f; file delete $t} err]} {
	catch {close $f}
	catch {file delete $t}
	return "can't write there ([lindex [split $err \n] 0])"
}
	return ""
}

#Tell owners the bot can't save its data (loader.3), or that it can again (loader.4)
proc blacktools:storage_check {} {
	set labels [dict create]
foreach {label dir} [blacktools:storage_dirs] { dict lappend labels $dir $label }
	set problems [list]
	set items [list]
dict for {dir what} $labels {
	set err [blacktools:storage_test $dir]
if {$err ne ""} {
	lappend problems $dir
	lappend items "folder $dir ([join $what ", "]): $err"
	}
}
	set problems [lsort $problems]
	set previous [blacktools:state_get storage_state]
if {$problems eq $previous} { return }
if {[blacktools:first_time storage $problems]} {
if {$problems ne ""} {
	putlog "\[BT\] WARNING: the bot can't save data: [join $items "; "]"
} else {
	putlog "\[BT\] Storage OK again: the bot can save its data."
	}
}
	set key [expr {$problems eq "" ? "loader.4" : "loader.3"}]
if {[blacktools:owner_notify $key [string range [join $items "; "] 0 350]] == 0} {
if {[blacktools:first_time storage_wait $problems]} {
	putlog "\[BT\] No boss owner could be told about the storage problem yet, trying again every 5 minutes."
}
	blacktools:schedule 300 blacktools:storage_check
	return
}
	blacktools:state_set storage_state $problems
}

proc blacktools:storage_hourly {min hour day month year} {
	catch blacktools:storage_check
}

bind time - "05 * * * *" blacktools:storage_hourly
blacktools:schedule 60 blacktools:load_notify
blacktools:schedule 70 blacktools:storage_check

#################
###########################################################################
##   END                                                                 ##
###########################################################################
