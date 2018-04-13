foreach pkg {sqlite3 Img  fileutil getstring} {
	package require $pkg
}
package require Plotchart 
namespace import getstring::*


#+########
#Settings
#+########
set logTestsNames ""
set logTestsIDs ""
set chosen_testID 1

set dstat_dataToSelect {
	memoryUsage "dstat agent/used//memory usage"
	totalCpuUsage "dstat agent/usr//total cpu usage"
	networkRecieve "dstat agent/recv//net/total"
	networkSend "dstat agent/send//net/total"
	newProcs "dstat agent/new//procs"
	diskRead "dstat agent/read//dsk/total"
	diskWrite "dstat agent/writ//dsk/total"
	totalCpuWait "dstat agent/wai//total cpu usage"
	concurrentUsers "Concurrent Users"
}
array set titles {
	memoryUsage "Memory Usage"
	totalCpuUsage "Total cpu usage"
	networkRecieve "Network received"
	networkSend "Network Sent"
	newProcs "New processes"
	diskRead "Disk read"
	diskWrite "Disk Write"
	totalCpuWait "Total cpu Wait"
	concurrentUsers "Concurrent Users"
}
#+########
#General functions
#+########
proc makeDb {} {
	
	plotDB eval {BEGIN IMMEDIATE TRANSACTION}
	plotDB eval {
		CREATE TABLE IF NOT EXISTS dstatdata (inputID INTEGER PRIMARY KEY autoincrement, 
			testID INT,
			concurrentUsers INT DEFAULT 0,
			totalCpuUsage REAL DEFAULT 0,
			totalCpuWait REAL DEFAULT 0,
			memoryUsage INT DEFAULT 0,
			networkRecieve INT DEFAULT 0,
			networkSend INT DEFAULT 0,
			newProcs INT DEFAULT 0,
			diskRead INT DEFAULT 0,
			diskWrite INT DEFAULT 0,
			time INT DEFAULT 0);}
		plotDB eval {	CREATE TABLE IF NOT EXISTS dstatTests (testID INTEGER PRIMARY KEY autoincrement, 	testFileName TEXT, testName TEXT COLLATE NOCASE);		}
		
		#This database could also be used in an array but it's easier to modify a sqlite databse using 
		#Firefox SQLite Manager than to modify the code:)
		#the plotName is the equivalent to the columns in dstatdata or other columns in other databases
		#plotDescription is the description used for the plot
		#plotMin is the minimum value that can exist
		#plotMax is the maximum value that can exist
		#plotXStep is the value that is used to increase the X-axe
		#plotYStep is the value that is used to increase the Y-axe
		#valueDecrement is the decrement used to modify the data to a human readable form
		#	for example 1024 to convert bytes to kilobytes
		plotDB eval {	
			CREATE TABLE IF NOT EXISTS plotInfo (plotinfoID INTEGER PRIMARY KEY autoincrement, 
			plotName TEXT COLLATE NOCASE,
			plotDescription TEXT COLLATE NOCASE,
			plotMin INT DEFAULT 0,
			plotMax INT DEFAULT 100,
			plotXStep INT DEFAULT 1,
			plotYStep INT DEFAULT 1,
			valueDecrement INT DEFAULT 1
			);		
		}
		#CREATE VIRTUAL TABLE IF NOT EXISTS BooksData USING fts4(bookid,bookpage, data);

		#Hardcoded for the moment..
		
	plotDB	eval {INSERT INTO plotInfo (plotName,plotDescription,plotMin,plotMax,plotXStep,plotYStep,valueDecrement)
		VALUES("totalCpuUsage","CPU Usage", 0, 100,10,1,1)}		
	plotDB	eval {INSERT INTO plotInfo (plotName,plotDescription,plotMin,plotMax,plotXStep,plotYStep,valueDecrement)
		VALUES("totalCpuWait","Total Cpu Wait", 0, 100,10,1,1)}		
	plotDB	eval {INSERT INTO plotInfo (plotName,plotDescription,plotMin,plotMax,plotXStep,plotYStep,valueDecrement)
		VALUES("memoryUsage","Memory in MB", 0, 100,1,1,1048576)}		
	plotDB	eval {INSERT INTO plotInfo (plotName,plotDescription,plotMin,plotMax,plotXStep,plotYStep,valueDecrement)
		VALUES("networkRecieve","KBps recieved", 0, 100,1,1,1024)}		
	plotDB	eval {INSERT INTO plotInfo (plotName,plotDescription,plotMin,plotMax,plotXStep,plotYStep,valueDecrement)
		VALUES("networkSend","KBps sent", 0, 100,1,1,1024)}		
	plotDB	eval {INSERT INTO plotInfo (plotName,plotDescription,plotMin,plotMax,plotXStep,plotYStep,valueDecrement)
		VALUES("diskRead","Disk read KB", 0, 100,1,1,1024)}		
	plotDB	eval {INSERT INTO plotInfo (plotName,plotDescription,plotMin,plotMax,plotXStep,plotYStep,valueDecrement)
		VALUES("diskWrite","Diskwrite KB", 0, 100,1,1,1024)}		

	plotDB eval {	
		CREATE TABLE IF NOT EXISTS topTest (topTestID INTEGER PRIMARY KEY autoincrement, 
		topTestName TEXT COLLATE NOCASE,
		topTestFilename TEXT COLLATE NOCASE,
		topTestDesc TEXT COLLATE NOCASE,
		topTestTime TEXT COLLATE NOCASE
		);		
	}
	
	plotDB eval {	
		CREATE TABLE IF NOT EXISTS topTestData (topTestDataID INTEGER PRIMARY KEY autoincrement, 
		topTestID INT,
		mbUsed INT,
		memoryPercentage REAL,
		cpuUsage REAL,
		timeRunning TEXT COLLATE NOCASE,
		process TEXT COLLATE NOCASE,
		sample INT
		);		
	}
	
	
	plotDB eval {	
		CREATE TABLE IF NOT EXISTS ioTest (ioID INTEGER PRIMARY KEY autoincrement, 
		ioTestName TEXT COLLATE NOCASE,
		ioTestFilename TEXT COLLATE NOCASE,
		ioTestDesc TEXT COLLATE NOCASE,
		ioTestTime TEXT COLLATE NOCASE
		);		
	}

	plotDB eval {	
		CREATE TABLE IF NOT EXISTS ioActivityData (ioDataID INTEGER PRIMARY KEY autoincrement, 
		ioID INT,
		device TEXT COLLATE NOCASE,
		tps REAL,
		sectors_read REAL,
		sectors_write REAL,
		average_sectors_size REAL,
		average_req_length REAL,
		await_ioRequests REAL,
		serviceTime REAL,
		cpu_usage REAL,
		sample INT
		);		
	}
	#Very important for distinct selects!
	
	plotDB eval {CREATE INDEX idx_process ON topTestData(process); CREATE INDEX idx_toptestid ON topTestData(topTestID) }
	plotDB eval {CREATE INDEX idx_ioID ON ioActivityData(ioID); CREATE INDEX idx_device ON ioActivityData(device)}
	
	
	plotDB eval {COMMIT TRANSACTION}
	puts "Database has been created, It's empty, enter the name of a test to be imported from CSV"
	getAllInfo 
}
#set wordList [regexp -inline -all -- {Users_(\d{1,})} {blabla_Users_5.csv blabla_Users_100.csv}]
#+########
#GUI stuff
#+########

#Plotchart documentation http://docs.activestate.com/activetcl/8.5/tklib/plotchart/plotchart.html#27
#Draw the gui/grid for the 4 info's we want to see..
# CPU usage, Memory, DISK and Network:D
proc drawGUI {} {
	#disable Motif tearoff interface!
	option add *Menu.tearOff 0
	#grid [canvas .c -background white] -sticky news
	#Menu thingy
	menu .menubar
    . configure -menu .menubar
    .menubar add cascade -label File -menu .menubar.file -underline 0
    menu .menubar.file
    #.menubar.file add command -label Import vApus dstat CSV -underline 0 -command putDataInSQLfromvApusDstat
    #.menubar.file add command -label Import TOP log -underline 0 -command putDataInSQLfromTOP
    .menubar.file add command -label "Import Logs (dstat CSV & TOP txt)" -underline 0 -command getAllInfo 
    .menubar.file add command -label "Save All the charts" -underline 0 -command saveAll
    .menubar.file add command -label "Save Current tab" -underline 5 -command save_current_canvas
    .menubar.file add separator
    .menubar.file add command -label Exit -underline 1 -command exit
    
    .menubar add cascade -label Options -menu .menubar.options -underline 0
	menu .menubar.options
    .menubar.options add command -label "Plot dstat" -underline 0 -command doPlot
    .menubar.options add command -label "Plot TOP charts" -underline 0 -command doPlotTop
    .menubar.options add command -label "Plot IO activity charts" -underline 0 -command doPlotSar
    
	menu .menubar.help
    .menubar add cascade -label Help -menu .menubar.help -underline 0
	.menubar.help add command -label "About" -underline 0 -command [list tk_messageBox -title "About" -icon info -message "VERSION 1.0b \n This is a vApus dstat log and Linux TOP 	log importer and plotter. \n It imports the logs in a SQLite database and then selects the data to plot.\n\nMade by Andrei clinciu"]
	
	
	#Combobox
	set ::cboLogs [ttk::combobox .cboimportedLogs -textvariable importedLogs] ; set ::importedLogs "Please select a log you want to plot"
	bind .cboimportedLogs <<ComboboxSelected>> switchPlot
	grid .cboimportedLogs
	grid config .cboimportedLogs -column 0 -row 0 -sticky news
	
	grid [ttk::notebook .nb  -width 800 -height 600 -padding 10] 
	.nb add [canvas .nb.t1 -width 800 -height 600] -text "Cpu Usage" 
	.nb add [canvas .nb.t2 -width 800 -height 600] -text "Memory usage"
	.nb add [canvas .nb.t3 -width 800 -height 600] -text "Disk Usage"
	.nb add [canvas .nb.t4 -width 800 -height 600] -text "Network Usage"
	.nb add [canvas .nb.t5 -width 800 -height 600] -text "CPU usage processes"
	.nb add [canvas .nb.t6 -width 800 -height 600] -text "Memory usage processes"
	.nb add [canvas .nb.t7 -width 800 -height 600] -text "IO SAR"

	#.nb select .nb.t1
	ttk::notebook::enableTraversal .nb

	#Events
	bind .nb <Configure> {doResize}

	bind . <F12> saveAll
	bind . <F2> getAllInfo
	bind . <Control-s>  save_current_canvas
	
	fillComboboxWithLogs
}

#+########
#Information and put in SQL db
#+########
proc getAllInfo {} {
	if {[tk_getString .gs testName "Enter the new test name"]} {
		putDataInSQLfromvApusDstat $testName
		putDataInSQLfromTOP $testName
		putDataInSQLfromSAR $testName
		if {[info exists ::cboLogs]} { 		fillComboboxWithLogs }
	}
}
proc putDataInSQLfromvApusDstat {testName} {
	#OR put this in another proc..?
	global dstat_dataToSelect
#	set allfiles [::fileutil::findByPattern $inputdir "*.txt *.csv"]
	
	set fileName [tk_getOpenFile -title "Chose CSV to import"]
	
	if {$fileName != ""} {
		set file [open $fileName r]
		
		#Read the first file with information
		gets $file stringRead
		#Split it by tabs
		set listStuff [split $stringRead \t]
		#Search the location of each information so we include it in the database
		foreach {header what} $dstat_dataToSelect {
			set statLocation($header) [lsearch -all $listStuff $what]
		}
		
		plotDB eval {BEGIN IMMEDIATE TRANSACTION}

		plotDB	eval {INSERT INTO dstatTests (testFileName,testName) VALUES($filename,$testName)}
		
		set testID [plotDB eval {SELECT testID FROM dstatTests WHERE testName=$testName}]
		puts "TestID : $testID"
		#Create the test
		#Read the file line per line and put it in the database.. at a location
		while {[gets $file stringRead] >= 0} {
			set listStuff [string map {, .} [split $stringRead \t]]
			
			set myVal [array names statLocation]
			foreach thing  $myVal {
				set value($thing) [lindex $listStuff $statLocation($thing)]
			}

			plotDB	eval {INSERT INTO dstatdata (testID,totalCpuUsage,totalCpuWait,memoryUsage,networkRecieve,networkSend,newProcs,diskRead,diskWrite,time)
				VALUES($testID,$value(totalCpuUsage),$value(totalCpuWait),$value(memoryUsage),$value(networkRecieve),$value(networkSend),$value(newProcs),$value(diskRead),$value(diskWrite),111)}		
		#	puts "Inserted some data"
		}

		plotDB eval {COMMIT TRANSACTION}
		
		puts "Done!"
	}

}
#Open the results from a top -b file, import it and analyze what processes used the most
#Count te total time TOP gave us information
#Select the total used memory & cpu per iteration
#find the applications using the most memory
#Or just add everything line per line in the DB and select everything afterwards.. 
#each top screen gets one db info per test and only adds the ones that have more memory..

proc putDataInSQLfromTOP {testName} {
	global dstat_dataToSelect

#	set allfiles [::fileutil::findByPattern $inputdir "*.txt *.csv"]
	
	set fileName [tk_getOpenFile -title "Chose top TXT file to import"]
	if {$fileName != ""} {
		set file [open $fileName r]
		set fileData [split [read $file] "\n"]
		set length [llength $fileData]

		plotDB	eval {INSERT INTO topTest (topTestName,topTestFilename,topTestDesc,topTestTime) 			VALUES($testName,$fileName,"Dunnow","")}
		set testID [plotDB eval {SELECT topTestID FROM topTest WHERE topTestName=$testName}]
		
		#TODO how to correctly import this?
		#Read the whole file line by line and analyse each one..
		#if "top - 11:08:42" type format is found, start a new db info
		#then forget the rest untill you reach the "  PID USER      PR  NI  VIRT  RES  SHR S %CPU %MEM    TIME+  COMMAND      " 
		#start to add each other one untill you get an empty line again and redo everything
		set newTop 0
		set topStarted 0 
		set sample 0
		#Start transaction so it goes faster..
		plotDB eval {BEGIN IMMEDIATE TRANSACTION}
		foreach line $fileData {
			#If a line is empty, just jump to the next one
			if {$line == ""} {
				if {$newTop && $topStarted} { set newTop 0 ; set topStarted 0 }
				continue 
			} 
			#If detected, go to next line anyway..
			if {!$newTop} { set newTop [regexp -all -- {top - \d{2}:\d{2}:\d{2}} $line] ; continue}
			if {!$topStarted} { set topStarted [string match -nocase {*PID*SHR*CPU*COMMAND*} $line]; incr sample 1 ; continue }
			
			#Include in DB
			#if {$oldTop == 0 && $newTop > 0} {				}
			#If there isn't a new top (thus new line or stupid data) nor the real data has started.. just continue
			if {!$newTop && !$topStarted} {		continue	}
			if {$newTop && !$topStarted} {		continue	}

				#using a foreach than using SET or lappend, lindex etc is much faster and has a greater efficiency
				foreach {PID USER   PR  NI  VIRT  RES  SHR S CPU MEM    TIME  COMMAND} $line { }

				plotDB	eval {INSERT INTO topTestData (topTestID,mbUsed,memoryPercentage,cpuUsage,timeRunning,process,sample) 	
					VALUES($testID,$RES,$MEM,$CPU,$TIME,$COMMAND,$sample)}	
			
			
		}
		plotDB eval {COMMIT TRANSACTION}
		
		close $file
		unset fileData
		puts "Done including top file..!"
	}
}

#Ignore the first 2 lines
#each 1 second "sample" has a few devices to add and also a header that has to be ignored..
#read untill the end of the file
proc putDataInSQLfromSAR {testName} {
	global dstat_dataToSelect

#	set allfiles [::fileutil::findByPattern $inputdir "*.txt *.csv"]
	
	set fileName [tk_getOpenFile -title "Chose sar - iostat - hard disk activity TXT file to import"]
	
	if {$fileName != ""} {
		set file [open $fileName r]
		#Read the file, split the newlines into list elements and remove the first two elements and replace them with nothing
		set fileData [lreplace [split [read $file] "\n"] 0 2]
		set length [llength $fileData]

		plotDB	eval {INSERT INTO ioTest (ioTestName,ioTestFilename,ioTestDesc,ioTestTime) 			VALUES($testName,$fileName,"Dunnow","")}
		set testID [plotDB eval {SELECT ioID FROM ioTest WHERE ioTestName=$testName}]
		
		set newSample 0
		set sample 0
		#Start transaction so it goes faster..
		plotDB eval {BEGIN IMMEDIATE TRANSACTION}
		foreach line $fileData {
			#If a line is empty, just jump to the next one
			if {$line == ""} {
				if {$newSample} { set newSample 0 ; incr sample 1 }
				continue 
			} 
			#12:28:56 PM       DEV       tps  rd_sec/s  wr_sec/s  avgrq-sz  avgqu-sz     await     svctm     %util
			#If new sample detected, go to next line anyway..
			if {!$newSample} { set newSample [string match -nocase {*DEV*avgqu-sz*await*util*} $line]; 			 ; continue }

			#Include in DB

			#using a foreach than using SET or lappend, lindex etc is much faster and has a greater efficiency
			foreach {time tloc device tps read_sec write_sec average_size average_queue await serviceTime cpu_usage} $line { }
			plotDB	eval {INSERT INTO ioActivityData (ioID,device,tps,sectors_read,sectors_write,average_sectors_size,average_req_length,await_ioRequests,serviceTime,cpu_usage,sample) 	
					VALUES($testID,$device,$tps,$read_sec,$write_sec,$average_size,$average_queue,$await,$serviceTime,$cpu_usage,$sample)}	
			
		}
		plotDB eval {COMMIT TRANSACTION}
		
		close $file
		unset fileData
		puts "Done including SAR IO activity file..!"
	}
}


#+########
#Switching plots
#+########
#Select per test.. (per sample?)
#Total CPU usage per sample
#Memory usage per sample

proc switchPlot {} {
	set idx [$::cboLogs current]
    if {[llength $idx] == 1} {
        set testID [lindex $::logTestsIDs $idx]
        set ::statusmsg "You've selected the testID $testID"
        set ::chosen_testID $testID
        doPlot
        doPlotTop
        doPlotSar
    }
}
proc fillComboboxWithLogs {} {
	global logTestsNames logTestsIDs 
	set logTestsNames ""
	set logTestsIDs  ""
	
	set tests [plotDB eval {SELECT testID,testName FROM dstatTests} ]
	foreach {testID testname} $tests {
		lappend logTestsNames $testname
		lappend logTestsIDs $testID	
		
	}
	puts "$logTestsNames \n\n"
	$::cboLogs configure -values $logTestsNames
}
#proc http://wiki.tcl.tk/11198 
proc canvas_save {w {filename ""}} {
	#Switch to that tab so it can be saved.. otherwise it will fail..
	puts "Saving $w"
	.nb select $w
	$w focus
	set im [image create photo -format window -data $w]
    if {$filename == ""} {
		set filename [tk_getSaveFile -defaultextension .png \
                      -filetypes {{png .png} {"All files" *}}]
	}
    if {$filename ne ""} {
        $im write $filename -format PNG
    }
    image delete $im
}
proc save_current_canvas {} {
	set w [.nb select]
	set im [image create photo -format window -data $w]
	set filename "charts/[.cboimportedLogs get]_[.nb tab $w -text].png"
    if {$filename ne ""} {
        $im write $filename -format PNG
    }
    image delete $im
}
proc saveAll {} {
	global chosen_testID

	if {[tk_getString .gs text "Enter files prefix:"]} {
		puts "user entered: $text"
	}
	catch { file mkdir charts }
	canvas_save .nb.t1 "charts/${text}_dstat_cpuUsage.png"
	canvas_save .nb.t2 "charts/${text}_dstat_memoryUsage.png"
	canvas_save .nb.t3 "charts/${text}_dstat_diskUsage.png"
	canvas_save .nb.t4 "charts/${text}_dstat_networkUsage.png"
	canvas_save .nb.t5 "charts/${text}_processes_using_CPU.png"
	canvas_save .nb.t6 "charts/${text}_processes_using_memory.png"
	canvas_save .nb.t7 "charts/${text}_IO_SAR.png"
	
	puts "Saved the images."
}

proc doPlot {} {
	global chosen_testID
    #
    # Clean up the contents (see also the note below!)
    #
    if {0} {
	foreach cnv {.c .c1 .c2 .c3} { subst {$cnv delete all} }

}
	.nb.t1 delete all
	.nb.t2 delete all
	.nb.t3 delete all
	.nb.t4 delete all
	
	plotChart .nb.t1  totalCpuUsage $chosen_testID "CPU Usage"
	plotChart .nb.t2  memoryUsage $chosen_testID "Memory usage"
	plotChart .nb.t3  "diskWrite diskRead" $chosen_testID "Disk usage"
	plotChart .nb.t4   "networkRecieve networkSend" $chosen_testID "Network traffic"	
}
proc doPlotTop {} {
	global chosen_testID
	findProcessAndMemoryFromTop $chosen_testID
}
proc doPlotSar {} {
	global chosen_testID

#clear the canvas..
	.nb.t7 delete all
	puts "Start the ioID"
	set devices [plotDB eval {SELECT DISTINCT device FROM ioActivityData WHERE ioID=:chosen_testID}]
	
	#X as = time
	#Y = avg qu-sz ?
	#Plot all devices:)r
	set count 0
	if {0} {
	foreach dev $devices {
		set val "(SELECT average_req_length FROM ioActivityData WHERE ioID=$chosen_testID )"
		if {$count > 0} { 	append dbColumns ,  $val  } else {	append  dbColumns  $val } 
		incr count
	}
	
	 set allValues [plotDB eval "SELECT $dbColumns FROM ioActivityData WHERE ioID=$chosen_testID"]
	 unset dbColumns
	 
 }
	puts "before the big selects"

	foreach dev $devices {
		#Disable the aditional step in between..
		append allValues [set values($dev) [plotDB eval "SELECT average_req_length FROM ioActivityData WHERE ioID=$chosen_testID AND device='$dev'"]] " "
		incr count
	}	
	 puts "after the big selects"
	set length [llength $values([lindex $devices 0])]
	#puts $allValues
	
	set minVal [tcl::mathfunc::min {*}$allValues]
    set maxVal [tcl::mathfunc::max {*}$allValues]

    set xnew 0.0
	set p [::Plotchart::createXYPlot .nb.t7  "0 $length [expr {$length/10}]" "$minVal $maxVal [expr {double($maxVal+1)/13}]" ]
	   
	unset allValues  
	$p title "IO average queue size"
	$p xtext "Samples (usually 1 sample per second)"
	$p ytext "Avg queue size"
	$p legendconfig -position top-left

	::Plotchart::colorMap cool
	
	#This formats the Y-axis
	#$p yconfig -format %.2f%% -ticklength 3 -ticklines 1
	$p yconfig -format %.2f -ticklength 3 -ticklines 1
	$p yticklines green
	 puts "You got here at least.."
	 
	foreach dev $devices color {red blue orange green yellow} {
		if {$dev != ""} {
			$p dataconfig "series${dev}" -colour $color
			$p legend "series${dev}" $dev		
			#puts "\n$dev with colour $color"
		}
	}
	puts "This is taking some time:D"
	set xnew 0
	puts "You have $devices aha?"

	for {set i 1} {$i<=$length} {incr i 1} {
		lappend xlist $i
	}	

	foreach dev $devices {
		$p plotlist "series${dev}" $xlist  $values($dev) 1
	}
	#findProcessAndMemoryFromTop $chosen_testID
}

proc doResize {} {
    global redo
    #
    # To avoid redrawing the plot many times during resizing,
    # cancel the callback, until the last one is left.
    #
    if { [info exists redo] } {
        after cancel $redo
    }
    set redo [after 500 doPlot]
}
#+########
#Plot drawing
#+########

#Plotchart generates a chart in the specified $canvas
# selectring the $columns sqlite databases, specify the FIRST one you want to use for the maximum/minimums
proc plotChart {canvas columns testID legendTitle} {
	global  titles decrement
	set dbColumns ""
	set count 0
	
	foreach col $columns {
		if {$count > 0} { append dbColumns , $col } else {	append  dbColumns  $col } 
		incr count
	}

    set values [plotDB eval "SELECT $dbColumns FROM dstatdata WHERE testID=:testID"]
	set firstcol [lindex $columns 0]
	set length [llength $values]
	
	#Select the plotInfo for the first column
	plotDB	eval {SELECT plotDescription,plotMin,plotMax,plotXStep,plotYStep,valueDecrement  FROM plotInfo WHERE plotName=$firstcol} plotInfo {}
	
	foreach val $values {
		lappend newValues [expr {$val/$plotInfo(valueDecrement)}]
	}
	
	#MAYBE USELESS->
	
	for {set i 0} {$i < $length} {incr i $count} { 
		lappend firstvalues [lindex $newValues $i]
	}
	#<-
	set minVal [tcl::mathfunc::min {*}$newValues]
    set maxVal [tcl::mathfunc::max {*}$newValues]

    set xnew 0.0
    #set yd	 10 	
		
	#set p [::Plotchart::createXYPlot $canvas  "0 [expr {[llength $firstvalues]/$count}] [expr {[llength $firstvalues]/$count/10}]" "$minVal $maxVal [expr {$maxVal/10}]" ]
	set p [::Plotchart::createXYPlot $canvas  "0 [expr {[llength $firstvalues]}] [expr {[llength $firstvalues]/10}]" "$minVal [expr {$maxVal+1}] [expr {$maxVal/13}]" ]
	   
	$p title $legendTitle
	$p xtext "Samples (usually 1 sample per second)"
	$p ytext $plotInfo(plotDescription)
	$p legendconfig -position top-left

	::Plotchart::colorMap cool
	
	#This formats the Y-axis
	#$p yconfig -format %.2f%% -ticklength 3 -ticklines 1
	$p yconfig -format %.2f -ticklength 3 -ticklines 1
	$p yticklines green
	
	$p dataconfig series0  -colour red 
	$p dataconfig series1  -colour blue
	$p dataconfig series2  -colour orange 
	$p dataconfig series3 -colour green 
	
	for {set i 0} {$i<$count} {incr i 1} {
		$p legend series${i} $titles([lindex $columns $i])
	}
	
	for {set i 0} {$i<$length} {incr i 1} {
		set ynew [expr {1*[lindex $newValues $i]}]
		
		if {[expr {$i%$count}]==0} { set xnew [expr {$xnew+1}] }
		
		$p plot "series[expr {$i%$count}]" $xnew $ynew	
	}
	

}

proc findProcessAndMemoryFromTop {topTestID} {
	global chosen_testID
#	set values [plotDB	eval {SELECT cpuUsage,memoryPercentage,Process FROM topTestData WHERE topTestID=$topTestID}]
	#Select the processes that use something more than 0.5
	set CPUprocesses [plotDB eval {SELECT DISTINCT process  FROM topTestData WHERE cpuUsage>1 AND topTestID=:chosen_testID  }]
	set MEMprocesses [plotDB eval {SELECT DISTINCT process  FROM topTestData WHERE memoryPercentage>0.05 AND topTestID=:chosen_testID }]
	
	#Select the total Cpu usage for a process
	set total 100
	foreach process $CPUprocesses {
		set val [plotDB eval {SELECT  total(cpuUsage)/(max(sample)/5)  FROM topTestData  WHERE process=:process AND topTestID=:chosen_testID }]
		#set val [plotDB eval {SELECT  total(cpuUsage)/count(cpuUsage)  FROM topTestData WHERE process=:process AND topTestID=:chosen_testID }]
		#set val [plotDB eval {SELECT  total(cpuUsage)/(count(sample)/(sample/topTestId))  FROM topTestData WHERE process=:process AND topTestID=:chosen_testID }]
		if {$val != "" && $process != ""} {
			if {$val >= 1} { lappend cpuUsageProcesses $process  $val }
			#set total [expr {$total -$val}]
		}
	}
	foreach process $MEMprocesses {
		set val [plotDB eval {SELECT  total(memoryPercentage)/(max(sample)/5)  FROM topTestData WHERE process=:process AND topTestID=:chosen_testID }]
		if {$val != "" && $process != ""} {
			lappend memUsageProcesses $process  $val
			#set total [expr {$total -$val}]
		}
	}
	#lappend processesCPU "Other/Idle"  $total

	.nb.t5 delete all
	::Plotchart::plotstyle configure default piechart labels placement out \
                                         piechart  labels sorted      1 \
                                         piechart  labels shownumbers 1 
                                         
	set s [::Plotchart::createPiechart .nb.t5]

	$s plot $cpuUsageProcesses
	$s title "Most CPU intensive processes"
	
	#Memory plot
	.nb.t6 delete all                                         
	set s [::Plotchart::createPiechart .nb.t6]

	$s plot $memUsageProcesses
	$s title "Most Memory intensive processes"
}

#+########
#Run Everything
#+########

if {![file exists "stresstest_info.sqlite"]} { sqlite3 plotDB ./stresstest_info.sqlite ; makeDb } else { sqlite3 plotDB ./stresstest_info.sqlite }
drawGUI

#canvas_save .c

