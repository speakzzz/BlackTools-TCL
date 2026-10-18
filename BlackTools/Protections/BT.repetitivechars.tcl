#########################################################################
##          BlackTools - The Ultimate Channel Control Script           ##
##                    One TCL. One smart Eggdrop                       ##
#########################################################################
#######################   RepetitiveChars TCL   #########################
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

proc repetitivechars:protect {nick host hand chan arg} {
global black
if {![validchan $chan]} { return }
	set handle [nick2hand $nick]
if {![botisop $chan] && ![setting:get $chan xonly]} { return }
if {[matchattr $handle $black(exceptflags) $chan]} { return }
if {[isbotnick $nick]} { return  }
	set bl_protect [blacktools:protect $nick $chan]
if {$bl_protect == "1"} { return }
	set getnum [setting:get $chan repetitivechars-char]
if {![string is integer -strict $getnum] || $getnum < 2} { set getnum $black(repetitivechars:num) }
#Fork change (speakzzz, 2026): check every run of identical characters in the
#message, not only the last one (before, "nooooooooo really" got through).
#Whitespace never counts and ends a run, so indented or aligned text is safe.
	set counter 0
	set current_char ""
foreach char [split $arg ""] {
if {[string is space $char]} {
	set current_char ""
	set counter 0
	continue
}
if {$char eq $current_char} {
	incr counter
} else {
	set current_char $char
	set counter 1
}
if {$counter >= $getnum} {
	blacktools:banner:1 $nick "repetitivechars" $chan $host [get:banmethod "repetitivechars" $chan] [link:chan:get $chan]
	return 1
	}
}
}
