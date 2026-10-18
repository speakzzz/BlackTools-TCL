#########################################################################
##          BlackTools - The Ultimate Channel Control Script           ##
##                    One TCL. One smart Eggdrop                       ##
#########################################################################
###########################   NoProxy TCL   #############################
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

###
#Fork change (speakzzz, 2026): the proxy lookup runs in the background.
#It used to make two synchronous requests per join, freezing the whole bot
#(no kicks, bans or replies) for up to 13 seconds each time, and threw a Tcl
#error whenever ip-api.com couldn't be reached. Now: one request per host,
#results cached for black(noproxy:cachetime) minutes, at most
#black(noproxy:rate) lookups a minute (ip-api.com's free limit is 45), and
#users who joined while a lookup was pending are handled when it returns.

if {![info exists black(noproxy:cachetime)]} { set black(noproxy:cachetime) 360 }
if {![info exists black(noproxy:rate)]} { set black(noproxy:rate) 40 }

proc noproxy:protect {nick host hand chan} {
    global black
if {![validchan $chan]} { return }
if {![setting:get $chan noproxy]} { return }
if {[matchattr $hand $black(exceptflags) $chan]} { return }
	set bl_protect [blacktools:protect $nick $chan]
if {$bl_protect == "1"} { return }
if {![botisop $chan] && ![setting:get $chan xonly]} { return }
    set uhost [lindex [split $host @] 1]
if {$uhost eq ""} { return }
foreach ex $black(noproxy:excepts) {
if {[string match -nocase $ex $uhost]} { return }
}
    set key [string tolower $uhost]
#cached answer
if {[info exists black(noproxy:cache:$key)]} {
    lassign $black(noproxy:cache:$key) when isp proxy
if {[unixtime] - $when < $black(noproxy:cachetime) * 60} {
if {$proxy eq "true"} { blacktools:noproxy_act $nick $host $chan $isp }
    return
    }
    unset black(noproxy:cache:$key)
}
#a lookup for this host is already running: wait for it
if {[info exists black(noproxy:wait:$key)]} {
    lappend black(noproxy:wait:$key) [list $nick $host $chan]
    return
}
#stay under the lookup service's rate limit
    set now [unixtime]
    set recent [list]
if {[info exists black(noproxy:times)]} {
foreach t $black(noproxy:times) { if {$now - $t < 60} { lappend recent $t } }
}
if {[llength $recent] >= $black(noproxy:rate)} {
    set black(noproxy:times) $recent
if {![info exists black(noproxy:limit_logged)] || $now - $black(noproxy:limit_logged) >= 60} {
    set black(noproxy:limit_logged) $now
    putlog "\[BT\] noproxy: more than $black(noproxy:rate) lookups a minute, skipping some joins for now."
    }
    return
}
    lappend recent $now
    set black(noproxy:times) $recent
    set black(noproxy:wait:$key) [list [list $nick $host $chan]]
if {[catch {blacktools:noproxy_lookup $key} err]} {
    unset -nocomplain black(noproxy:wait:$key)
    blacktools:noproxy_logerror $err
    }
}

proc blacktools:noproxy_lookup {key} {
    global black
if {![info exists black(http_ok)]} {
if {[catch {package require http}] != 0} {
    source $black(backdir)/BlackTools/Addons/http.tcl
    package require http
    }
    set black(http_ok) 1
}
    ::http::config -useragent "lynx"
    ::http::geturl "http://ip-api.com/json/${key}?fields=status,proxy,isp" -timeout 5000 \
	-command [list blacktools:noproxy_done $key]
}

#Log lookup problems at most once every 10 minutes, so an outage doesn't flood the log
proc blacktools:noproxy_logerror {err} {
    global black
    set now [unixtime]
if {[info exists black(noproxy:error_logged)] && $now - $black(noproxy:error_logged) < 600} { return }
    set black(noproxy:error_logged) $now
    putlog "\[BT\] noproxy: proxy lookup failed ([string range [regsub -all {[\x00-\x1f]+} $err " "] 0 150]); joins are not being checked meanwhile."
}

proc blacktools:noproxy_done {key token} {
    global black
    set status [::http::status $token]
    set data ""
if {$status eq "ok" && [::http::ncode $token] == 200} { set data [::http::data $token] }
    ::http::cleanup $token
    set waiting [list]
if {[info exists black(noproxy:wait:$key)]} {
    set waiting $black(noproxy:wait:$key)
    unset black(noproxy:wait:$key)
}
if {![regexp {"status"\s*:\s*"success"} $data]} {
    blacktools:noproxy_logerror "status $status"
    return
}
    set proxy "false"
    set isp ""
    regexp {"proxy"\s*:\s*(true|false)} $data -> proxy
    regexp {"isp"\s*:\s*"([^"]*)"} $data -> isp
#keep the cache from growing without limit
if {[llength [array names black noproxy:cache:*]] > 2000} {
foreach k [array names black noproxy:cache:*] { unset black($k) }
}
    set black(noproxy:cache:$key) [list [unixtime] $isp $proxy]
if {$proxy ne "true"} { return }
foreach w $waiting {
    lassign $w nick host chan
#only act on users who are still there, with the same host, and while the protection is still on
if {![validchan $chan] || ![setting:get $chan noproxy] || ![onchan $nick $chan]} { continue }
if {![string equal -nocase [getchanhost $nick $chan] $host]} { continue }
    blacktools:noproxy_act $nick $host $chan $isp
    }
}

proc blacktools:noproxy_act {nick host chan isp} {
	blacktools:banner:2 $nick "noproxy" $chan $chan $host "0" [list $isp]
if {[link:status $chan] == "1"} {
	foreach c [link:chan:get $chan] {
	blacktools:banner:2 $nick "noproxy" $c $c $host "1" [list $isp]
				}
	blacktools:link_ban2 [link:get] 0
		} else { who:chan $chan }
}

##############
#########################################################################
##   END                                                               ##
#########################################################################