#########################################################################
##          BlackTools - The Ultimate Channel Control Script           ##
##                    One TCL. One smart Eggdrop                       ##
#########################################################################
########################   ANTIBADTEXT TCL   ############################
#########################################################################
##						                       ##
##   BlackTools  : http://blacktools.tclscripts.net	               ##
##   Bugs report : http://www.tclscripts.net/	                       ##
##   GitHub page : https://github.com/tclscripts/BlackToolS-TCL	       ##
##   Online Help : irc://irc.undernet.org/tcl-help 	               ##
##                 #TCL-HELP / UnderNet                                ##
##                 You can ask in english or romanian                  ##
##					                               ##
#########################################################################

############################# AntiColor ################################

proc colortext:process {nick host hand chan arg type} {
	global black
if {![validchan $chan]} { return }
	set handle [nick2hand $nick]
if {![botisop $chan] && ![setting:get $chan xonly]} { return }
if {[matchattr $handle $black(exceptflags) $chan]} { return }
if {[isbotnick $nick]} { return }
	set bl_protect [blacktools:protect $nick $chan]
if {$bl_protect == "1"} { return }
#Fork change (speakzzz, 2026): anticolor also catches hex colors (\004) and
#reverse (\026), and every hit returns 1 so the protections after this one
#don't punish the same message again.
switch $type {
anticolor {
	set codes [list "\003" "\004" "\026"]
}
antibold  {
	set codes [list "\002"]
}
antiunderline {
	set codes [list "\037"]
	}
}
if {$type == "anticolor" && $black(anticolor:specific_colors) != ""} {
	foreach c $black(anticolor:specific_colors) {
if {[string first $c $arg] >= 0} {
	blacktools:banner:1 $nick [string toupper "$type"] $chan $host [get:banmethod $type $chan] [link:chan:get $chan]
	return 1
		}
	}
	return
}
foreach code $codes {
if {[string first $code $arg] >= 0} {
	blacktools:banner:1 $nick [string toupper "$type"] $chan $host [get:banmethod $type $chan] [link:chan:get $chan]
	return 1
	}
}
}

proc anticolor:protect {nick host hand chan arg} {
	colortext:process $nick $host $hand $chan $arg "anticolor"
}

############################# AntiBold ################################

proc antibold:protect {nick host hand chan arg} {
	colortext:process $nick $host $hand $chan $arg "antibold"
}

############################ AntiUnderline ###############################

proc antiunderline:protect {nick host hand chan arg} {
	colortext:process $nick $host $hand $chan $arg "antiunderline"
}

############################## AntiCaps #################################

proc anticaps:protect {nick host hand chan arg} {
global black botnick
	set handle [nick2hand $nick]
	set found_caps 0
if {![validchan $chan]} { return }
if {![botisop $chan] && ![setting:get $chan xonly]} { return }
if {[matchattr $handle $black(exceptflags) $chan]} { return }
	set bl_protect [blacktools:protect $nick $chan]
if {$bl_protect == "1"} { return }
if {[isbotnick $nick]} { return }
#Fork change (speakzzz, 2026): capitals are counted as a share of the
#letters, not of the whole message, so spaces and punctuation can't dilute
#shouting ("H E L L O", "HELLO!!!!!!"). Nicks of people on the channel and
#emoticons (":D", ":-P", "XD") are left out. Messages need 20+ characters
#and 10+ letters.
	set words [list]
foreach a [split $arg] {
if {$a eq "" || [onchan $a $chan]} { continue }
if {[regexp {[[:punct:]]} $a] && [regexp {^[^A-Za-z]*[A-Za-z]?[^A-Za-z]*$} $a]} { continue }
if {[regexp -nocase {^x[dp]+$} $a]} { continue }
	lappend words $a
}
	set text [join $words " "]
if {[string length $text] < 20} { return }
	set letters [regexp -all {[A-Za-z]} $text]
	set capitals [regexp -all {[A-Z]} $text]
if {$letters < 10 || $capitals == 0} { return }
if {100 * $capitals / $letters > $black(anticapscount)} {
	set found_caps 1
}
if {$found_caps == "1"} {
	blacktools:banner:1 $nick "ANTICAPS" $chan $host [get:banmethod "anticaps" $chan] [link:chan:get $chan]	
	return 1	
	}
}


##############
#########################################################################
##   END                                                               ##
#########################################################################
