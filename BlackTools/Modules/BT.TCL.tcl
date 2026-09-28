#########################################################################
##          BlackTools - The Ultimate Channel Control Script           ##
##                    One TCL. One smart Eggdrop                       ##
#########################################################################
###############################   TCL   #################################
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

proc tcl:process {nick host hand chan chan1 type the_script who} {
	global black config
	set cmd_status [btcmd:status $chan $hand "tcl" 0]
if {$cmd_status == "1"} { 
	return 
}
	set current_tcl ""
	set tcl_exists 0

if {$who == ""} {
if {$type == "0"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr "tcl"
}
if {$type == "1"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_nick "tcl"
}
if {$type == "2"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_priv "tcl"
}
	return
}

switch $who {

wget {
if {$the_script == ""} {
if {$type == "0"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr "tcl"
}
if {$type == "1"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_nick "tcl"
}
if {$type == "2"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_priv "tcl"
}
	return
}

	set current_tcl [tcl:url_filename $the_script]
if {$current_tcl == ""} {
if {$type == "0"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr "tcl"
}
if {$type == "1"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_nick "tcl"
}
if {$type == "2"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_priv "tcl"
}
	return
}
if {[check:if:valid $current_tcl] == "1"} {
	blacktools:tell $nick $host $hand $chan $chan1 tcl.21 $current_tcl
	return
}
	tcl:download_start $the_script $current_tcl [list $nick $host $hand $chan $chan1] 0
}
	
load {
if {$the_script == ""} {
if {$type == "0"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr "tcl"
}
if {$type == "1"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_nick "tcl"
}
if {$type == "2"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_priv "tcl"
}
	return
}
if {![tcl:valid_name $the_script]} {
if {$type == "0"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr "tcl"
}
if {$type == "1"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_nick "tcl"
}
if {$type == "2"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_priv "tcl"
}
	return
}
if {[check:if:valid $the_script] == "0"} {
	blacktools:tell $nick $host $hand $chan $chan1 tcl.12 $the_script
	return
}
if {[string match -nocase "*BlackTools*" $the_script]} {
	blacktools:tell $nick $host $hand $chan $chan1 tcl.18 none
	return
}
	set black(tcl_load) [catch {source "$black(dirname)/$the_script"} black(tcl_load_error)]
	
if {$black(tcl_load) == "1"} {
	blacktools:tell $nick $host $hand $chan $chan1 tcl.3 "$the_script [split $black(tcl_load_error)]"
	return
}
	set file [open "$config" r]
	set w [read -nonewline $file]
	close $file
	set counter -1
	set data [split $w "\n"]
	set tcl_position -1
	set found_it 0
foreach line $data {
if {[string match -nocase "source $black(dirname)/*" $line]} {
	set the_split [split $line "/"]
	set script [lindex $the_split 1]
if {[string equal -nocase $script $the_script]} {
	set found_it 1
		}		
	}
}
if {$found_it == 1} {
	blacktools:tell $nick $host $hand $chan $chan1 tcl.4 $the_script
	return
}
if {[catch {tcl:config_write [concat $data [list "source $black(dirname)/$the_script"]]} err]} {
	blacktools:tell $nick $host $hand $chan $chan1 tcl.3 "$the_script [split $err]"
	return
}
	rehash
	blacktools:tell $nick $host $hand $chan $chan1 tcl.5 $the_script

}
unload {
if {$the_script == ""} {
if {$type == "0"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr "tcl"
}
if {$type == "1"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_nick "tcl"
}
if {$type == "2"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_priv "tcl"
}
	return
}
if {![tcl:valid_name $the_script]} {
if {$type == "0"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr "tcl"
}
if {$type == "1"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_nick "tcl"
}
if {$type == "2"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_priv "tcl"
}
	return
}
if {[string match -nocase "*BlackTools*" $the_script]} {
	blacktools:tell $nick $host $hand $chan $chan1 tcl.18 none
	return
}

	set file [open "$config" r]
	set w [read -nonewline $file]
	close $file
	set counter -1
	set data [split $w "\n"]
	set tcl_position -1
	set found_it 0
foreach line $data {
	set counter [expr $counter + 1]
if {[string match -nocase "*source $black(dirname)/*" $line]} {
	set the_split [split $line "/"]
	set script [lindex $the_split 1]
if {[string equal -nocase $script $the_script]} {
	set found_it 1
	set tcl_position $counter
			}	
		}
	}
if {$found_it == 0} {
	blacktools:tell $nick $host $hand $chan $chan1 tcl.7 $the_script
	return
}

	set delete [lreplace $data $tcl_position $tcl_position]
if {[catch {tcl:config_write $delete} err]} {
	blacktools:tell $nick $host $hand $chan $chan1 tcl.3 "$the_script [split $err]"
	return
}
	rehash
	blacktools:tell $nick $host $hand $chan $chan1 tcl.8 [split $the_script]
}

list {
	set the_files [glob -directory $black(dirname) "*.tcl"]
	set current_tcl ""
	set counter 0
	set found_tcl 0
	set timestamp [clock format [clock seconds] -format {%Y%m%d%H%M%S}]
	set temp "$black(tempdir)/tcl_temp.$timestamp"
	array set tcllist [list]
	set num_l 1
	set num 0
foreach file $the_files {
	set split_file [split $file "/"]
	set the_file [lindex $split_file 1]
if {[string match -nocase "*.tcl" $the_file]} {
	set found_tcl 1
}
	set status [check:if:load $the_file]
if {$status == "1"} {
	lappend tcllist(1) $the_file
	} else {
	lappend tcllist(2) $the_file
	}
	unset status
}

if {$found_tcl == "0"} {
	blacktools:tell $nick $host $hand $chan $chan1 tcl.2 "tcl"
	return
}

	set tempwrite [open $temp w]
foreach n [lsort -integer -increasing [array names tcllist]] {
foreach tcl $tcllist($n) {
	set counter [expr $counter + 1]
if {$n == "1"} {
	puts $tempwrite "$counter \002$tcl\002"
	} elseif {$n == "2"} {
	puts $tempwrite "$counter $tcl"
		}
	}
}
	close $tempwrite
	
	set file [open $temp "r"]
	set w [read -nonewline $file]
	close $file
	set data [split $w "\n"]
	file delete $temp
	module:getinfo $nick $host $hand $chan $chan1 $type $data "tcl" "0" $the_script
	}
info {
if {$the_script == ""} {
if {$type == "0"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr "tcl"
}
if {$type == "1"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_nick "tcl"
}
if {$type == "2"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_priv "tcl"
}
	return
}
if {![tcl:valid_name $the_script]} {
if {$type == "0"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr "tcl"
}
if {$type == "1"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_nick "tcl"
}
if {$type == "2"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_priv "tcl"
}
	return
}
	set status_valid [check:if:valid $the_script]
	set status [check:if:load $the_script]
if {$status_valid == "0"} {
	blacktools:tell $nick $host $hand $chan $chan1 tcl.12 $the_script
	return
	}
if {$status == "0"} {
	blacktools:tell $nick $host $hand $chan $chan1 tcl.13 $the_script
} else {
	blacktools:tell $nick $host $hand $chan $chan1 tcl.14 $the_script
			}
		}
default {
if {$type == "0"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr "tcl"
}
if {$type == "1"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_nick "tcl"
}
if {$type == "2"} {
	blacktools:tell $nick $host $hand $chan $chan1 gl.instr_priv "tcl"
}
	return
		}
	}
}

proc check:if:valid {tcl} {
	global black
	set the_files [glob -directory $black(dirname) "*.tcl"]
	foreach file $the_files {
	set split_file [split $file "/"]
	set the_file [lindex $split_file 1]
if {[string equal -nocase $tcl $the_file]} {
	return 1
	}
}
	return 0
}

proc check:if:load {tcl} {
	global black config
	set file [open "$config" r]
	set w [read -nonewline $file]
	close $file
	set data [split $w "\n"]
	set return [lsearch -all -inline -exact $data "source $black(dirname)/$tcl"]
if {$return != ""} {
	return 1
} else {
	return 0
	}
}

###
#Fork changes (speakzzz, 2026): safe script names, HTTPS-only async download
#via Tcl's http package (no wget), atomic eggdrop.conf writes.

set black(tcl_download_maxsize) 1048576
set black(tcl_download_timeout) 30000

#A script name: letters, digits, dot, dash, underscore; ends in .tcl; no paths.
proc tcl:valid_name {name} {
if {[string length $name] > 64} { return 0 }
if {[string first ".." $name] >= 0} { return 0 }
	return [regexp {^[A-Za-z0-9][A-Za-z0-9._-]*\.[Tt][Cc][Ll]$} $name]
}

#Returns the script file name from an https:// URL, or "" if the URL is not acceptable.
proc tcl:url_filename {url} {
if {![regexp {^https://[A-Za-z0-9.-]+(:[0-9]+)?/[^\s\"'`<>]*$} $url]} { return "" }
	set path [lindex [split $url "?#"] 0]
	set name [lindex [split $path "/"] end]
if {![tcl:valid_name $name]} { return "" }
	return $name
}

proc tcl:tls_setup {} {
if {[info procs blacktools:update_tls_register] ne ""} {
	blacktools:update_tls_register
	return
}
	package require http
	set tlsver [package require tls]
	set opts [list -ssl2 0 -ssl3 0 -tls1 0 -tls1.1 0 -tls1.2 1 -require 1]
if {[package vcompare $tlsver 1.7.11] >= 0} { lappend opts -autoservername 1 }
foreach cafile {/etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/cert.pem /usr/local/share/certs/ca-root-nss.crt} {
if {[file readable $cafile]} { lappend opts -cafile $cafile ; break }
}
	::http::register https 443 [list ::tls::socket {*}$opts]
}

#ctx = {nick host hand chan chan1}
proc tcl:download_start {url name ctx redirects} {
	global black
if {[catch {tcl:tls_setup} err]} {
	tcl:download_fail $name $ctx "TLS is not available ($err)"
	return
}
#identity encoding: the -progress size check does not run on compressed responses
if {[catch {::http::geturl $url -binary 1 -timeout $black(tcl_download_timeout) \
	-headers [list Accept-Encoding identity] \
	-progress tcl:download_progress \
	-command [list tcl:download_done $url $name $ctx $redirects]} err]} {
	tcl:download_fail $name $ctx $err
	}
}

#Abort downloads that grow past the size limit
proc tcl:download_progress {token total current} {
	global black
if {$current > $black(tcl_download_maxsize) || $total > $black(tcl_download_maxsize)} {
	::http::reset $token toobig
	}
}

proc tcl:download_done {url name ctx redirects token} {
	global black
	set status [::http::status $token]
	set code [::http::ncode $token]
	set meta [::http::meta $token]
	set body [::http::data $token]
	::http::cleanup $token
if {$status eq "ok" && [string length $body] > $black(tcl_download_maxsize)} { set status "toobig" }
if {$status eq "toobig"} {
	tcl:download_fail $name $ctx "file is larger than [expr {$black(tcl_download_maxsize) / 1024}] KB"
	return
}
if {$status ne "ok"} {
	tcl:download_fail $name $ctx "connection $status"
	return
}
if {$code in {301 302 303 307 308}} {
	set location ""
foreach {k v} $meta {
if {[string equal -nocase $k "Location"]} { set location $v }
}
if {$redirects >= 3} {
	tcl:download_fail $name $ctx "too many redirects"
	return
}
if {![string match "https://*" $location]} {
	tcl:download_fail $name $ctx "redirect to a non-https address was refused"
	return
}
	tcl:download_start $location $name $ctx [expr {$redirects + 1}]
	return
}
if {$code != 200} {
	tcl:download_fail $name $ctx "server replied HTTP $code"
	return
}
if {[regexp -nocase {^\s*<(!doctype|html)} $body]} {
	tcl:download_fail $name $ctx "the link returned a web page, not a script (use the raw file link)"
	return
}
if {![info complete $body]} {
	tcl:download_fail $name $ctx "the file is not a complete Tcl script"
	return
}
	set target "$black(dirname)/$name"
	set part "$black(dirname)/.$name.part"
if {[file exists $target]} {
	tcl:download_fail $name $ctx "a file with this name already exists"
	return
}
if {[catch {
	set f [open $part w]
	fconfigure $f -translation binary
	puts -nonewline $f $body
	close $f
	file rename $part $target
} err]} {
	catch {close $f}
	file delete -force $part
	tcl:download_fail $name $ctx $err
	return
}
	lassign $ctx nick host hand chan chan1
	blacktools:tell $nick $host $hand $chan $chan1 tcl.20 $name
}

#Tell the user it failed; the technical reason goes only to them, by notice.
proc tcl:download_fail {name ctx reason} {
	lassign $ctx nick host hand chan chan1
	#never let error text break the IRC line (newlines would start a new raw command)
	set reason [string range [regsub -all {[\x00-\x1f]+} $reason " "] 0 300]
	blacktools:tell $nick $host $hand $chan $chan1 tcl.19 $name
	putserv "NOTICE $nick :\[BT\] $name: $reason"
	putlog "\[BT\] tcl download of $name by $hand failed: $reason"
}

#Write eggdrop.conf atomically: temp file, then rename over the original.
proc tcl:config_write {lines} {
	global config
	set tmp "$config.bt-tmp"
	set f [open $tmp w]
	catch {file attributes $tmp -permissions [file attributes $config -permissions]}
if {[catch {puts $f [join $lines "\n"]; close $f} err]} {
	catch {close $f}
	file delete -force $tmp
	error $err
}
	file rename -force $tmp $config
}

##############
#########################################################################
##   END                                                               ##
#########################################################################
