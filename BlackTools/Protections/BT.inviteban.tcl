#########################################################################
##          BlackTools - The Ultimate Channel Control Script           ##
##                    One TCL. One smart Eggdrop                       ##
#########################################################################
##########################   INVITEBAN TCL   ############################
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

#Fork change (speakzzz, 2026): the inviter's host is taken from the INVITE
#itself (nick!user@host). Before, the bot asked the server with USERHOST and
#took the next USERHOST reply as the answer, but other features (secure mode,
#!ub, !sb, ...) ask too, so an unrelated user could be banned as the inviter.
#In an invite flood only the first inviter was handled, with the last invite's
#channel in the reason, because the channel was kept in one global variable.
proc inviteban:protect {from type arg} {
	global black
	set invitechan [string trimleft [lindex [split $arg] 1] ":"]
if {![string match "*!*@*" $from]} { return 0 }
	set nick [lindex [split $from "!"] 0]
	set mask [join [lrange [split $from "!"] 1 end] "!"]
if {[string equal -nocase $nick $black(chanserv)] || [isbotnick $nick]} { return 0 }
	set channels ""
foreach chan [channels] {
	set bl_protect [blacktools:protect $nick $chan]
if {$bl_protect == "1"} { continue }
if {[matchattr [nick2hand $nick $chan] $black(exceptflags) $chan]} { continue }
	lappend channels $chan
}
if {$channels != ""} {
	inviteban:act $channels 0 $mask $invitechan $nick
}
	return 0
}

#No longer used; kept so a USERHOST bind left over from before an update
#removes itself instead of causing an error.
proc inviteban:gethost {from keyword arguments} {
	check:if:bind "inviteban:gethost" "302"
	return 0
}

proc inviteban:act {channels num mask invitechan nick} {
	global black
	set chan [join [lindex [split $channels] $num]]
	set inc 0
if {$chan == ""} {
	return
}
if {[setting:get $chan inviteban]} {
if {[onchan $nick $chan]} {
	blacktools:banner:2 $nick "INVITEBAN:[encoding convertto utf-8 $invitechan]" $chan $chan $mask "0" ""
	who:chan $chan
	}
}
	set inc [expr {$num + 1}]
if {[lindex $channels $inc] != ""} {
	utimer 5 [list inviteban:act $channels $inc $mask $invitechan $nick]
	}
}

##############
#########################################################################
##   END                                                               ##
#########################################################################
