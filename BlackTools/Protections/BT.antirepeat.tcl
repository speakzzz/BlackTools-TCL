#########################################################################
##          BlackTools - The Ultimate Channel Control Script           ##
##                    One TCL. One smart Eggdrop                       ##
#########################################################################
########################   ANTIREPEAT TCL   #############################
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

#Fork change (speakzzz, 2026): messages are compared ignoring capitalization,
#formatting codes and extra spaces, so "buy now", "BUY NOW" and "buy  now"
#count as the same message. Timers are matched exactly, so a message
#containing * or ? can no longer cancel the timers of other messages.
proc antirepeat:normalize {text} {
	set text [color:filter $text]
	regsub -all -- {\004([0-9A-Fa-f]{6}(,[0-9A-Fa-f]{6})?)?|[\021\035\036]} $text "" text
	return [string tolower [join [regexp -all -inline {\S+} $text] " "]]
}

proc antirepeat:protect {nick host hand chan arg} {
global black botnick
	set arg [antirepeat:normalize $arg]
if {$arg eq ""} { return }
	set handle [nick2hand $nick]
if {![validchan $chan]} { return }
if {![botisop $chan] && ![setting:get $chan xonly]} { return }
if {[matchattr $handle $black(exceptflags) $chan]} { return }
	set bl_protect [blacktools:protect $nick $chan]
if {$bl_protect == "1"} { return }
if {[isbotnick $nick]} { return }
	set repeatset [setting:get $chan antirepeat-setting]
if {$repeatset == ""} { set repeatset "$black(antirepeat:repeats)" }
	set number [scan $repeatset %\[^:\]]
	set time [scan $repeatset %*\[^:\]:%s]
	set cmd [list antirepeat:remove $host $chan $arg]
foreach tmr [utimers] {
if {[lindex $tmr 1] eq $cmd} {
	killutimer [lindex $tmr 2]
	}
}

if {![info exists black(repeat:$host:$chan:$arg)]} { 
	set black(repeat:$host:$chan:$arg) 0 
}
	incr black(repeat:$host:$chan:$arg)
	utimer $time $cmd

if {$black(repeat:$host:$chan:$arg) >= $number} {
	blacktools:banner:1 $nick "ANTIREPEAT" $chan $host [get:banmethod "antirepeat" $chan] [link:chan:get $chan]
	antirepeat:remove $host $chan $arg
	return 1
	}
}

proc antirepeat:remove {host chan arg} {
	global black
	set cmd [list antirepeat:remove $host $chan $arg]
foreach tmr [utimers] {
if {[lindex $tmr 1] eq $cmd} {
	killutimer [lindex $tmr 2]
	}
}

if {[info exists black(repeat:$host:$chan:$arg)]} {
	unset black(repeat:$host:$chan:$arg)
	}
}

proc antirepeat:protect:me {nick host hand chan keyword arg} {
	antirepeat:protect $nick $host $hand $chan $arg
}

##############
#########################################################################
##   END                                                               ##
#########################################################################
