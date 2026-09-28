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

#################
###########################################################################
##   END                                                                 ##
###########################################################################
