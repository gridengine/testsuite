#___INFO__MARK_BEGIN__
##########################################################################
#
#  The Contents of this file are made available subject to the terms of
#  the Sun Industry Standards Source License Version 1.2
#
#  Sun Microsystems Inc., March, 2001
#
#
#  Sun Industry Standards Source License Version 1.2
#  =================================================
#  The contents of this file are subject to the Sun Industry Standards
#  Source License Version 1.2 (the "License"); You may not use this file
#  except in compliance with the License. You may obtain a copy of the
#  License at http://gridengine.sunsource.net/Gridengine_SISSL_license.html
#
#  Software provided under this License is provided on an "AS IS" basis,
#  WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING,
#  WITHOUT LIMITATION, WARRANTIES THAT THE SOFTWARE IS FREE OF DEFECTS,
#  MERCHANTABLE, FIT FOR A PARTICULAR PURPOSE, OR NON-INFRINGING.
#  See the License for the specific provisions governing your rights and
#  obligations concerning the Software.
#
#  The Initial Developer of the Original Code is: Sun Microsystems, Inc.
#
#  Copyright: 2001 by Sun Microsystems, Inc.
#
#  All Rights Reserved.
#
##########################################################################
#___INFO__MARK_END__


#****** config/verify_config() **************************************************
#  NAME
#     verify_config() -- verify testsuite configuration setup
#
#  SYNOPSIS
#     verify_config { config_array only_check parameter_error_list } 
#
#  FUNCTION
#     This procedure will verify or enter setup configuration
#
#  INPUTS
#     config_array         - array name with configuration (ts_config)
#     only_check           - if 1: don't ask user, just check
#     parameter_error_list - returned list with error information
#
#  RESULT
#     number of errors
#
#  SEE ALSO
#     check/verify_host_config()
#     check/verify_user_config()
#*******************************************************************************
proc verify_config { config_array only_check parameter_error_list } {
   global actual_ts_config_version
   upvar $config_array config
   upvar $parameter_error_list error_list

   return [verify_config2 config $only_check error_list $actual_ts_config_version]
}



proc verify_config2 { config_array only_check parameter_error_list expected_version } {

   global CHECK_OUTPUT be_quiet
   upvar $config_array config
   upvar $parameter_error_list error_list

   set errors 0
   set error_list ""
   
   if { ! [ info exists config(version) ] } {
      puts $CHECK_OUTPUT "Could not find version info in configuration file"
      lappend error_list "no version info"
      incr errors 1
      return -1
   }

   if { $config(version) != $expected_version } {
      # CR: TODO implement update hook for additional checktrees 
      #          They are called when the version doesn't match
      #          The update hook may be implemented like in setup2 which is
      #          calling update_ts_config_version() till the version matches
      #          the setup_hooks_0_version specified in additional checktree.tcl file
      #          It seems to be the case that some checktrees (arco) already have
      #          a configuration update procedure. But this is not defined global.
      #          It has to be evaluated if this solution should be used in general!
      puts $CHECK_OUTPUT "Configuration file version \"$config(version)\" not supported."
      puts $CHECK_OUTPUT "Expected version is \"$expected_version\""
      lappend error_list "unexpected version"
      incr errors 1
      return -1      
   } else {
      debug_puts "Configuration Version: $config(version)"
   }

   set max_pos [get_configuration_element_count config]
   
   set uninitalized ""
   if { $be_quiet == 0 } { 
      puts $CHECK_OUTPUT ""
   }

   for { set param 1 } { $param <= $max_pos } { incr param 1 } {
      set par [ get_configuration_element_name_on_pos config $param ]
      set status "ok"
      if { $be_quiet == 0 } { 
         puts -nonewline $CHECK_OUTPUT "   $config($par,desc) ..."
         flush $CHECK_OUTPUT
      }
      if { $config($par) == "" } {
         set status "not initialized"
         lappend uninitalized $param
         if { $only_check != 0 } {
            lappend error_list ">$par< configuration not initalized"
            incr errors 1
         }
      } else {
         set procedure_name  $config($par,setup_func)
         set default_value   $config($par,default)
         set description     $config($par,desc)
         if { [string length $procedure_name] == 0 } {
             debug_puts "no procedure defined"
             set status "no check"
         } else {
            if { [info procs $procedure_name ] != $procedure_name } {
               puts $CHECK_OUTPUT "error\n"
               puts $CHECK_OUTPUT "-->WARNING: unkown procedure name: \"$procedure_name\" !!!"
               puts $CHECK_OUTPUT "   ======="
               lappend uninitalized $param
               set status "unknown check function"

               if { $only_check == 0 } { 
                  wait_for_enter 
               }
            } else {
               # call procedure only_check == 1
               debug_puts "starting >$procedure_name< (verify mode) ..."
               set value [ $procedure_name 1 $par config ]
               if { $value == -1 } {
                  set status "failed"
                  incr errors 1
                  lappend error_list $par
                  lappend uninitalized $param
                  puts $CHECK_OUTPUT "error\n"
                  puts $CHECK_OUTPUT "-->WARNING: verify error in procedure \"$procedure_name\" !!!"
                  puts $CHECK_OUTPUT "   ======="

               } 
            }
         }
      }
      if { $be_quiet == 0 } { 
         puts $CHECK_OUTPUT "\r   $config($par,desc) ... $status"
      }
   } 
   if { [set count [llength $uninitalized]] != 0 && $only_check == 0} {
      puts $CHECK_OUTPUT "$count parameters are not initialized!"
      puts $CHECK_OUTPUT "Entering setup procedures ..."
      foreach pos $uninitalized {
         wait_for_enter
         clear_screen
         set p_name [get_configuration_element_name_on_pos config $pos]
         set procedure_name  $config($p_name,setup_func)
         set default_value   $config($p_name,default)
         set description     $config($p_name,desc)
       
         puts $CHECK_OUTPUT "----------------------------------------------------------"
         puts $CHECK_OUTPUT $description
         puts $CHECK_OUTPUT "----------------------------------------------------------"
         debug_puts "Starting configuration procedure for parameter \"$p_name\" ($config($p_name,pos)) ..."
         set use_default 0
         if { [string length $procedure_name] == 0 } {
            puts $CHECK_OUTPUT "no procedure defined"
            set use_default 1
         } else {
            if { [info procs $procedure_name ] != $procedure_name } {
               puts $CHECK_OUTPUT ""
               puts $CHECK_OUTPUT "-->WARNING: unkown procedure name: \"$procedure_name\" !!!"
               puts $CHECK_OUTPUT "   ======="
               if { $only_check == 0 } { wait_for_enter }
               set use_default 1
            }
         } 

         if { $use_default != 0 } {
            # we have no setup procedure
            if { $default_value != "" } {
               puts $CHECK_OUTPUT "using default value: \"$default_value\"" 
               set config($p_name) $default_value 
            } else {
               puts $CHECK_OUTPUT "No setup procedure and no default value found!!!"
               if { $only_check == 0 } {
                  puts -nonewline $CHECK_OUTPUT "Please enter value for parameter \"$p_name\": "
                  set value [wait_for_enter 1]
                  puts $CHECK_OUTPUT "using value: \"$value\"" 
                  set config($p_name) $value
               } 
            }
         } else {
            # call setup procedure ...
            debug_puts "starting >$procedure_name< (setup mode) ..."
            set value [ $procedure_name 0 $p_name config ]
            if { $value != -1 } {
               puts $CHECK_OUTPUT "using value: \"$value\"" 
               set config($p_name) $value
            }
         }
         if { $config($p_name) == "" } {
            puts $CHECK_OUTPUT "" 
            puts $CHECK_OUTPUT "-->WARNING: no value for \"$p_name\" !!!"
            puts $CHECK_OUTPUT "   ======="
            incr errors 1
            lappend error_list $p_name
         }
      }
   }

   return $errors
}

#****** config/edit_setup() *****************************************************
#  NAME
#     edit_setup() -- edit testsuite/host/user configuration setup
#
#  SYNOPSIS
#     edit_setup { array_name verify_func mod_string } 
#
#  FUNCTION
#     This procedure is used to change the testsuite setup configuration
#
#  INPUTS
#     array_name  - ts_config, ts_host_config or ts_user_config array name
#     verify_func - procedure used for verify changes
#     mod_string  - name of string to report changes
#
#  SEE ALSO
#     check/verify_config()
#     check/verify_host_config()
#     check/verify_user_config()
#*******************************************************************************
proc edit_setup { array_name verify_func mod_string } {
   global ts_config
   global CHECK_OUTPUT
   global CHECK_DEFAULTS_FILE 
   global env

   upvar $array_name org_config
   upvar $mod_string onchange_values


   set onchange_values ""
   set org_names [ array names org_config ]
   foreach name $org_names {
#      puts $CHECK_OUTPUT "config $name = $org_config($name)"
      set config($name) $org_config($name)
   }

   set no_changes 1
   while { 1 } {
      clear_screen
      puts $CHECK_OUTPUT "----------------------------------------------------------"
      puts $CHECK_OUTPUT "$config(version,desc)"
      puts $CHECK_OUTPUT "----------------------------------------------------------"

      set max_pos [get_configuration_element_count config]
      set index 1
      for { set param 1 } { $param <= $max_pos } { incr param 1 } {
         set par [ get_configuration_element_name_on_pos config $param ]
     
         set procedure_name  $config($par,setup_func)
         if { [ string compare "" $procedure_name ] == 0 } {
            continue
         }
          
         if { [info procs $procedure_name ] == $procedure_name } {
            set index_par_list($index) $par
   
            if { $index <= 9 } {
               puts $CHECK_OUTPUT "    $index) $config($par,desc)"
            } else {
               puts $CHECK_OUTPUT "   $index) $config($par,desc)"
            }
            incr index 1
         }
      }
      puts $CHECK_OUTPUT ""
      puts $CHECK_OUTPUT "Please enter the number of the configuration parameter"
      puts -nonewline $CHECK_OUTPUT "you want to change or return to exit: "
      set input [ wait_for_enter 1]
   
      if { [ info exists index_par_list($input) ] } {
         set no_changes 0
         set back [$config($index_par_list($input),setup_func) 0 $index_par_list($input) config ]
         if { $back != -1 } {
            puts $CHECK_OUTPUT "setting $index_par_list($input) to:\n\"$back\"" 
            set config($index_par_list($input)) $back
            wait_for_enter
         } else {
            puts $CHECK_OUTPUT "setup error"
            wait_for_enter
         }
      } else {
         if { [string compare $input ""] == 0 } {
            break
         }
         puts $CHECK_OUTPUT "\"$input\" is not a valid number"
      }
   }

   if { $no_changes == 1 } {
      return -1
   }

   puts $CHECK_OUTPUT ""
   # modified values
   set no_changes 0
   set org_names [ array names org_config ]
   foreach name $org_names {
      if { [ info exists config($name) ] != 1 } {
         incr no_changes 1
         break
      }
      if { [ string compare $config($name) $org_config($name)] != 0 } {
         incr no_changes 1
         break
      }
   }
   # added values
   set new_names [ array names config ]      
   foreach name $new_names {
      if { [ info exists org_config($name)] != 1 } {
         incr no_changes 1
         break
      }
   }
   if { $no_changes == 0 } {
      return -1
   }

   puts $CHECK_OUTPUT "Verify new settings..."
   set verify_state "-1"
   lappend errors "edit_setup(): verify func not found"
   if { [info procs $verify_func ] == $verify_func } {
      set errors ""
      set verify_state [$verify_func config 1 errors ]
   }
   if { $verify_state == 0 } {
      puts $CHECK_OUTPUT ""
      # modified values
      set org_names [ array names org_config ]
      foreach name $org_names {
         if { [ info exists config($name) ] != 1 } {
            puts $CHECK_OUTPUT "removed $name:"
            puts $CHECK_OUTPUT "old value: \"$org_config($name)\""
            continue
         }
         if { [ string compare $config($name) $org_config($name)] != 0 } {
            puts $CHECK_OUTPUT "modified $name:"
            puts $CHECK_OUTPUT "old value: \"$org_config($name)\""
            puts $CHECK_OUTPUT "new value: \"$config($name)\"\n"
         }
      }
      # added values
      set new_names [ array names config ]      
      foreach name $new_names {
         if { [ info exists org_config($name)] != 1 } {
            puts $CHECK_OUTPUT "added $name:"
            puts $CHECK_OUTPUT "value: \"$config($name)\"\n"
         }
      }

      puts -nonewline $CHECK_OUTPUT "Do you want to use your changes? (y/n) > "
      set input [ wait_for_enter 1 ]
      if { [ string compare $input "y" ] == 0 } {
         # save values (modified, deleted)
         set org_names [ array names org_config ]
         foreach name $org_names {
            if { [ info exists config($name) ] != 1 } {
               unset org_config($name)
               if { [ info exists config($name,onchange)] } {
                  append onchange_values $config($name,onchange)
               }
               continue
            }
            if { [ string compare $config($name) $org_config($name)] != 0 } {
               set org_config($name) $config($name)
               if { [ info exists config($name,onchange)] } {
                  append onchange_values $config($name,onchange)
               }
            }
         }
         # save values (added)
         set new_names [ array names config ]      
         foreach name $new_names {
            if { [ info exists org_config($name)] != 1 } {
               set org_config($name) $config($name) 
               if { [ info exists config($name,onchange)] } {
                  append onchange_values $config($name,onchange)
               }
            }
         }


         return 0
      }
   } else {
      puts $CHECK_OUTPUT "Verify errros:"
      foreach elem $errors {
         puts $CHECK_OUTPUT "error in: $elem"
      }
      wait_for_enter
   }
   puts $CHECK_OUTPUT "resetting old values ..."
   $verify_func org_config 1 errors 
   return -1
}



#****** config/show_config() ****************************************************
#  NAME
#     show_config() -- show configuration settings
#
#  SYNOPSIS
#     show_config { conf_array {short 1} { output "not_set" } } 
#
#  FUNCTION
#     This procedure will print the current configuration settings for the
#     global configuration arrays: ts_config, ts_user_config or ts_host_config
#
#  INPUTS
#     conf_array - ts_config, ts_user_config or ts_host_config
#     {short 1}  - if 0: show long parameter names
#     {output "not_set"} - if set this string will contain the output
#
#  SEE ALSO
#     ???/???
#*******************************************************************************
proc show_config { conf_array {short 1} { output "not_set" } } {
   global CHECK_OUTPUT

   set do_standard_output 1
   upvar $conf_array config
   if { $output != "not_set" } {
      upvar $output output_string
      set do_standard_output 0
   }

   set max_pos [get_configuration_element_count config]
   set max_par_length 0
   set max_description_length 0
   for { set param 1 } { $param <= $max_pos } { incr param 1 } {
      set par [ get_configuration_element_name_on_pos config $param ]
      set description     $config($par,desc)
      
      set par_length [string length $par]
      set description_length [string length $description]
      if { $max_par_length < $par_length } {
         set max_par_length $par_length
      }
      if { $max_description_length < $description_length} {
         set  max_description_length $description_length
      }
   }
   for { set param 1 } { $param <= $max_pos } { incr param 1 } {
      set par [ get_configuration_element_name_on_pos config $param ]
      set procedure_name  $config($par,setup_func)
      set default_value   $config($par,default)
      set description     $config($par,desc)
      set value           $config($par)
      if { $do_standard_output == 1 } {
         if { $short == 0 } {
            puts $CHECK_OUTPUT "$description:[get_spaces [expr ( $max_description_length - [ string length $description ] ) ]] \"$config($par)\""
         } else {
            puts $CHECK_OUTPUT "$par:[get_spaces [expr ( $max_par_length - [ string length $par ] ) ]] \"$config($par)\""
         }
      } else {
         if { $short == 0 } {
            append output_string "$description:[get_spaces [expr ( $max_description_length - [ string length $description ] ) ]] \"$config($par)\"\n"
         } else {
            append output_string "$par:[get_spaces [expr ( $max_par_length - [ string length $par ] ) ]] \"$config($par)\"\n"
         }
      }
   }
}

#****** config/modify_setup2() **************************************************
#  NAME
#     modify_setup2() -- modify testsuite setup files
#
#  SYNOPSIS
#     modify_setup2 { } 
#
#  FUNCTION
#     This procedure is called to let the user change testsuite settings
#
#  INPUTS
#
#  SEE ALSO
#     check/setup2()
#*******************************************************************************
proc modify_setup2 {} {
   global ts_checktree ts_config ts_host_config ts_user_config ts_db_config 
   global CHECK_ACT_LEVEL CHECK_OUTPUT CHECK_PACKAGE_DIRECTORY check_name


   lock_testsuite

   set old_exed $ts_config(execd_hosts)
   set old_master $ts_config(master_host)
   set old_root $ts_config(product_root)

   set change_level ""
   
   set check_name "setup"
   set CHECK_ACT_LEVEL "0"
   
   
   set setup_hook(1,name) "Testsuite configuration"
   set setup_hook(1,config_array) "ts_config"
   set setup_hook(1,verify_func)  "verify_config"
   set setup_hook(1,save_func)    "save_configuration"
   
   
   set setup_hook(2,name) "Host file configuration"
   set setup_hook(2,config_array) "ts_host_config"
   set setup_hook(2,verify_func)  "verify_host_config"
   set setup_hook(2,save_func)    "save_host_configuration"
   set setup_hook(2,filename)     "$ts_config(host_config_file)"
   
   set setup_hook(3,name) "User file configuration"
   set setup_hook(3,config_array) "ts_user_config"
   set setup_hook(3,verify_func)  "verify_user_config"
   set setup_hook(3,save_func)    "save_user_configuration"
   set setup_hook(3,filename)     "$ts_config(user_config_file)"
   
   set setup_hook(4,name) "Database file configuration"
   set setup_hook(4,config_array) "ts_db_config"
   set setup_hook(4,verify_func)  "verify_db_config"
   set setup_hook(4,save_func)    "save_db_configuration"
   set setup_hook(4,filename)     "$ts_config(db_config_file)"

   set numSetups 4
   set numAddConfigs [llength $ts_config(additional_config)]
   
   for {set i 0} { $i < $ts_checktree(act_nr)} {incr i 1 } {
      for {set ii 0} {[info exists ts_checktree($i,setup_hooks_${ii}_name)]} {incr ii 1} {
         incr numSetups 1
         puts $CHECK_OUTPUT "found setup hook $ts_checktree($i,setup_hooks_${ii}_name)"
         set setup_hook($numSetups,name)         $ts_checktree($i,setup_hooks_${ii}_name)
         set setup_hook($numSetups,config_array) $ts_checktree($i,setup_hooks_${ii}_config_array)
         global $setup_hook($numSetups,config_array)
         set setup_hook($numSetups,init_func)   $ts_checktree($i,setup_hooks_${ii}_init_func)
         set setup_hook($numSetups,verify_func)  $ts_checktree($i,setup_hooks_${ii}_verify_func)
         set setup_hook($numSetups,save_func)    $ts_checktree($i,setup_hooks_${ii}_save_func)
         set setup_hook($numSetups,init_func) $ts_checktree($i,setup_hooks_${ii}_init_func)

         if {[info exists ts_checktree($i,setup_hooks_${ii}_filename)]} {
            set setup_hook($numSetups,filename) $ts_checktree($i,setup_hooks_${ii}_filename)
         }
      }
   }
   

    while { 1 } {
      clear_screen
      puts $CHECK_OUTPUT "--------------------------------------------------------------------"
      puts $CHECK_OUTPUT "Modify testsuite configuration"
      puts $CHECK_OUTPUT "--------------------------------------------------------------------"
      
      for { set i 1 } { $i <= $numSetups } { incr i 1 } {
         puts $CHECK_OUTPUT [format "    (%d) %-27s (%ds) %s" $i $setup_hook($i,name) $i $setup_hook($i,name)]
      }   
         
      puts $CHECK_OUTPUT ""
      for { set a 1 } { $a <= $numAddConfigs } { incr a 1 } {
         set key [expr ($numSetups + $a)]
         set addConfig($key,name) [file tail [lindex $ts_config(additional_config) [expr ($a -1)]]]
         set addConfig($key,fullName) [lindex $ts_config(additional_config) [expr ($a -1)]]
         puts $CHECK_OUTPUT [format "    (%ds) %s" $key "configuration for $addConfig($key,name)"]
      }
      puts $CHECK_OUTPUT ""
      puts -nonewline $CHECK_OUTPUT "Please enter a number or press return to exit: "
      set input [ wait_for_enter 1]
      if { [string compare $input ""] == 0 } {
         break
      }
      set do_show 0
      if { [set pos [string first "s" $input ]] > 0 } {
         set do_show 1
         incr pos -1
         set input [string range $input 0 $pos]
      }
      if { $input > 0 && $input <= $numSetups && [info exists setup_hook($input,config_array)] } {
         if { $do_show == 0 } {
            set do_save [edit_setup $setup_hook($input,config_array) $setup_hook($input,verify_func) tmp_string]
            if { $do_save == 0 } {
               if { [info exists setup_hook($input,filename)] } {
                  $setup_hook($input,save_func) $setup_hook($input,filename) 
               } else {
                  $setup_hook($input,save_func)
               }
               append change_level $tmp_string
            }
         } else {
            puts $CHECK_OUTPUT "show_config $setup_hook($input,config_array)"
            show_config $setup_hook($input,config_array)
         }
      } else {
         if { $input > $numSetups && $input <= [expr ($numAddConfigs+$numSetups)] && $do_show != 0} {
            puts $CHECK_OUTPUT "configuration for additional config file:\n$addConfig($input,fullName)"
            get_additional_config $addConfig($input,fullName) add_configuration
            show_config add_configuration
         } else {
            puts $CHECK_OUTPUT "no valid number ($input)"
         }
      }
      wait_for_enter
   }


   # onchange:   "", "compile", "install", "stop"
   debug_puts "change_level: \"$change_level\""

   if { [string length $change_level] != 0 } { 
      puts $CHECK_OUTPUT "modification needs shutdown of old grid engine system"
      set new_exed $ts_config(execd_hosts)
      set new_master $ts_config(master_host)
      set new_root $ts_config(product_root)
      set ts_config(execd_hosts)  $old_exed
      set ts_config(master_host)  $old_master
      set ts_config(product_root) $old_root
      shutdown_core_system 0 1
      delete_tests $ts_config(checktree_root_dir)/install_core_system
      set ts_config(execd_hosts)  $new_exed
      set ts_config(master_host)  $new_master
      set ts_config(product_root) $new_root
   }

   if { [ string first "stop" $change_level ] >= 0 } {
      puts $CHECK_OUTPUT "modification needs restart of testsuite."
      exit 1
   }

   if { [ string first "compile" $change_level ] >= 0 } {
      if { $CHECK_PACKAGE_DIRECTORY != "none" } {
         puts $CHECK_OUTPUT "modification needs reinstallation of packages"
         prepare_packages ;# reinstall tar binaries
      } else { 
         puts $CHECK_OUTPUT "modification needs compilation of new grid engine system"
         compile_source
      }
   }
   unlock_testsuite
   return $change_level
}

#****** config/config_generic() ************************************************
#  NAME
#     config_generic() -- Get generic configuration values
#
#  SYNOPSIS
#     config_generic { only_check name config_array help_text check_type } 
#
#  FUNCTION
#     This procedure is used to get standard (generic) testsuite configuration
#     values for setting up the testsuite. Possible values are e.g. getting
#     a list of hosts from testsuite host configuration file, a string value,
#     a filename, ...
#
#  INPUTS
#     only_check   - If set no parameter is read from stdin (startup check mode)
#     name         - Configuration parameter name
#     config_array - The configuration array where the value is stored
#     help_text    - A description of the configuration value for the user
#     check_type   - The values data type requested from the user.
#                    Possible types are:
#                    "host":      request a host from host config
#                    "hosts":     request a list of hosts from host config
#                    "port":      request a valid portnumber
#                    "directory": request a directory path
#                    "string":    request a string value
#                    "boolean":   request "true" or "false" string
#                    "filename":  request a path to existing file
#                    "choice" :   request a value from the list $choice_list
#                                 the parameter choice_list is mandatory
#     { choice_list "" } - The list of values from which the value is choosed
#
#  RESULT
#     The value of the configuration parameter or "-1" on error
#
#  EXAMPLE
#     proc config_hedeby_product_root { only_check name config_array } {
#        global CHECK_OUTPUT fast_setup
#        upvar $config_array config
#        
#        set help_text { "Please enter the path where the testsuite should install Hedeby,"
#                        "or press >RETURN< to use the default value." 
#                        "WARNING: The compile option will remove the content of this directory" 
#                        "or store it to \"testsuite_trash\" directory with testsuite_trash commandline option!!!" }
#      
#        set value [config_generic $only_check $name config $help_text "directory" ]
#        if {!$fast_setup} {
#           # to be able to find processes with ps command, don't allow to long
#           # directory path:
#           set add_path "/bin/sol-sparc64/abcdef"
#           set path_length [ string length $add_path ]
#           if { [string length "$value/$add_path"] > 60 } {
#                puts $CHECK_OUTPUT "path for hedeby dist directory is too long (must be <= [expr ( 60 - $path_length )] chars)"
#                puts $CHECK_OUTPUT "The testsuite tries to find processes via ps output most ps output is truncated"
#                puts $CHECK_OUTPUT "for longer lines."
#                return -1
#           }
#        }
#        return $value
#     }
#*******************************************************************************
proc config_generic { only_check name config_array help_text check_type {choice_list ""} } {
   global CHECK_OUTPUT CHECK_USER ts_host_config ts_user_config ts_db_config
   global fast_setup 

   upvar $config_array config

   set actual_value  $config($name)
   if { [info exists config($name,default)] } {
      set default_value $config($name,default)
   } else {
      set default_value ""
   }
   # this parameter is not used ...
   if { [info exists config($name,desc)] } {
      set description $config($name,desc)
   } else {
      set description ""
   }
   set value $actual_value
   if { $actual_value == "" && $check_type != "host" && $check_type != "hosts"} {
      set value $default_value
      if { $default_value == "" } {
         set value "none"
      }
   }
  
   if { $only_check == 0 } {
      switch -- $check_type {
         "hosts" {
            set value [config_select_host_list config $name $value $help_text]
         }
         "host" {
            set value [config_select_host_list config $name $value $help_text 1]
         }
         "choice" {
            upvar $choice_list choices
            set index 0
            puts $help_text
            foreach item $choices {
               incr index 1
               puts "($index) $item"
            }
            puts "\n"
            puts -nonewline "Please enter value/number or return to exit: "
            set value [ wait_for_enter 1 ]
            if { [string length $value] > 0 } {
               if { [string is integer $value] } {
                  incr value -1
                  set value [ lindex $choices $value ]
               }   
            }
            if { [ lsearch $choices $value ] < 0 } {
               puts "value \"$value\" not found in list"
               return -1
            }
         }
         default {
            # do setup  
            foreach elem $help_text { puts $CHECK_OUTPUT $elem }
            puts $CHECK_OUTPUT "(default: $value)"
            puts -nonewline $CHECK_OUTPUT "> "
            set input [ wait_for_enter 1]
            if { [ string length $input] > 0 } {
               set value $input
            } else {
               puts $CHECK_OUTPUT "using default value"
            }
         }
      }
   } 

   # now verify
   if {!$fast_setup} {
         switch -- $check_type {
         "port" {
            # check that user has a port list
            if { [ info exists ts_user_config($CHECK_USER,portlist) ] != 1 } {
               puts $CHECK_OUTPUT "User $CHECK_USER has not portlist entry in user configuration"
               return -1
            }
            # check that port value is >= 0
            if { $value < 0  } {
               puts $CHECK_OUTPUT "Port \"$value\" is not >= 0"
               return -1;
            }
            # check that string is an integer
            if { [string is integer $value] == 0 } {
               puts $CHECK_OUTPUT "Port \"$value\" is not a integer"
               return -1;
            }
            # check that value is <= 65535
            if { $value > 65535 } {
               puts $CHECK_OUTPUT "Port \"$value\" is > 65535"
               return -1;
            }
            # check that user has the portlist entry
            if { $value != 0 } {
               if { [ expr ( $value % 2 ) == 0 ] } {
                  # an even port - ok
                  if { [ lsearch $ts_user_config($CHECK_USER,portlist) $value] < 0 } {
                     puts $CHECK_OUTPUT "Port \"$value\" not in portlist of user $CHECK_USER" 
                     return -1
                  }
               } else {
                  # NOT an even port - this is a workaround, because user can only add even ports!
                  set even_port_value $value
                  incr even_port_value -1
                  if { [ lsearch $ts_user_config($CHECK_USER,portlist) $even_port_value] < 0 } {
                     puts $CHECK_OUTPUT "Port \"$value\" not in portlist of user $CHECK_USER" 
                     return -1
                  }
               }
            }
         }
         "directory" {
            # is full path ?
            if { [ string first "/" $value ] != 0 } {
               puts $CHECK_OUTPUT "Path \"$value\" doesn't start with \"/\""
               return -1
            }
       
            if { [tail_directory_name $value] != $value } {
               puts $CHECK_OUTPUT "\nPath \"$value\" is not a valid directory name, try \"[tail_directory_name $value]\""
               return -1
            }

            # is directory ?
            if { [ file isdirectory $value ] != 1 } {
               puts $CHECK_OUTPUT "Directory \"$value\" not found"
               return -1
            }
         }
         "filename" {
            if {[file isfile $value] != 1} {
               puts "no such file $value"
               return -1
            }
         }
         "host" {
            # this must be a testsuite host
         }
         "hosts" {
            # this must be a testsuite host list
         }
         "string" {
            # do we want to check strings ?
         }
         "boolean" {
            # this must be "true" or "false"
            if { $value != "true" && $value != "false" } {
               puts $CHECK_OUTPUT "Boolean must be \"true\" or \"false\""
               return -1
            }
         }
         "choice" {
            # already checked
         }
         default {
            add_proc_error "hedeby_conf_generic" -2 "unexpected generic config type: $check_type"
            return -1
         }
      }
   }
   return $value
}

#****** config/config_testsuite_root_dir() **************************************
#  NAME
#     config_testsuite_root_dir() -- testsuite root directory setup
#
#  SYNOPSIS
#     config_testsuite_root_dir { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_testsuite_root_dir { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_TESTSUITE_LOCKFILE
   global CHECK_USER
   global CHECK_GROUP
   global env fast_setup

   upvar $config_array config
   
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)

   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
      # do setup
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter the full pathname of the testsuite root directory, or press >RETURN<"
      puts $CHECK_OUTPUT "to use the default value. If you want to test with root permissions (which is"
      puts $CHECK_OUTPUT "neccessary for a full testing) the root user must have read permissions for this"
      puts $CHECK_OUTPUT "directory."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value [tail_directory_name $input]
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   # now verify
   if { ! $fast_setup } {
      # is full path ?
      if { [ string first "/" $value ] != 0 } {
         puts $CHECK_OUTPUT "Path \"$value\" doesn't start with \"/\""
         return -1
      }

      if { [tail_directory_name $value] != $value } {
         puts $CHECK_OUTPUT "\nPath \"$value\" is not a valid directory name, try \"[tail_directory_name $value]\""
         return -1
      }

      # is file ?
      if { [ file isfile $value/check.exp ] != 1 } {
         puts $CHECK_OUTPUT "File \"$value/check.exp\" not found"
         return -1
      }
   }

   # set global variables to value
   set CHECK_TESTSUITE_LOCKFILE "$value/testsuite_lockfile"

   if {[catch {set CHECK_USER [set env(USER)] }] != 0} {
      set CHECK_USER [file attributes $value/check.exp -owner]
      puts $CHECK_OUTPUT "\nNo USER is set!\n(default: $CHECK_USER)\n"
      set env(USER) $CHECK_USER
   } 

   # if USER env. variable is empty
   if { $CHECK_USER == "" } {
      set CHECK_USER [file attributes $value/check.exp -owner]
      puts $CHECK_OUTPUT "\nNo USER is set!\n(default: $CHECK_USER)\n"
      set env(USER) $CHECK_USER
   }

   if {[catch {set CHECK_GROUP [set env(GROUP)] }] != 0} {
      set CHECK_GROUP [file attributes $value/check.exp -group]
      puts $CHECK_OUTPUT "\nNo GROUP is set!\n(default: $CHECK_GROUP)\n"
      set env(GROUP) $CHECK_GROUP
   }

   return $value
}


#****** config/config_checktree_root_dir() **************************************
#  NAME
#     config_checktree_root_dir() -- checktree root setup
#
#  SYNOPSIS
#     config_checktree_root_dir { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_checktree_root_dir { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_TESTSUITE_LOCKFILE
   global CHECK_USER
   global CHECK_GROUP
   global env fast_setup

   upvar $config_array config
   
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)

   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
      if { $default_value == "" } { 
         set value $config(testsuite_root_dir)/checktree
      }
   }

   if { $only_check == 0 } {
      # do setup
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter the full pathname of the testsuite checktree directory, or press >RETURN<"
      puts $CHECK_OUTPUT "to use the default value."
      puts $CHECK_OUTPUT "The checktree directory contains all tests in its subdirectory structure."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value [tail_directory_name $input]
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   }

   # now verify

   if {!$fast_setup} {
      # is full path ?
      if { [ string first "/" $value ] != 0 } {
         puts $CHECK_OUTPUT "Path \"$value\" doesn't start with \"/\""
         return -1
      }

      if { [tail_directory_name $value] != $value } {
         puts $CHECK_OUTPUT "\nPath \"$value\" is not a valid directory name, try \"[tail_directory_name $value]\""
         return -1
      }

      # is file ?
      if { [ file isdirectory $value ] != 1 } {
         puts $CHECK_OUTPUT "Directory \"$value\" not found"
         return -1
      }
   }

   return $value
}



proc config_additional_checktree_dirs { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_TESTSUITE_LOCKFILE
   global CHECK_USER
   global CHECK_GROUP
   global env fast_setup

   upvar $config_array config
   
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)

   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
      if { $default_value == "" } { 
         set value "none"
      }
   }

   if { $only_check == 0 } {
      # do setup
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter the full pathname of an additional checktree directory or press >RETURN<"
      puts $CHECK_OUTPUT "to use the default value."
      puts $CHECK_OUTPUT "The checktree directory contains all tests in its subdirectory structure. You can"
      puts $CHECK_OUTPUT "add more than one directory by using a space as separator."
      puts $CHECK_OUTPUT "If you enter the keyword \"none\" no additional checktree directory is supported."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   }

   # now verify

   if {!$fast_setup} {
      set not_set 1 
      foreach directory $value {
         if { $directory == "none" } {
            set not_set 0
         }
      }

      if { $not_set == 1 } {
         set new_value ""
         foreach directory $value {
            append new_value " [tail_directory_name $directory]"
         }
         set value [string trim $new_value]

         foreach directory $value {
            # is full path ?
            if { [ string first "/" $directory ] != 0 } {
               puts $CHECK_OUTPUT "Path \"$directory\" doesn't start with \"/\""
               return -1
            }

            if { [tail_directory_name $directory] != $directory } {
               puts $CHECK_OUTPUT "\nPath \"$directory\" is not a valid directory name, try \"[tail_directory_name $directory]\""
               return -1
            }

            # is file ?
            if { [ file isdirectory $directory ] != 1 } {
               puts $CHECK_OUTPUT "Directory \"$directory\" not found"
               return -1
            }
         }
      } else {
         set value "none"
      }
   }

   return $value
}


proc config_additional_config { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_TESTSUITE_LOCKFILE
   global CHECK_USER
   global CHECK_GROUP
   global env fast_setup

   upvar $config_array config
   
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)

   set value $actual_value
   if {$actual_value == ""} {
      set value $default_value
      if {$default_value == ""} { 
         set value "none"
      }
   }

   if {$only_check == 0} {
      # do setup
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter the full pathname of an additional testsuite configuration"
      puts $CHECK_OUTPUT "used for installing a secondary Grid Engine cluster,"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "You can add more than one configuration file by using a space as separator."
      puts $CHECK_OUTPUT "If you enter the keyword \"none\" no additional configuration will be used."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [wait_for_enter 1]
      if {[string length $input] > 0} {
         set value $input
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   }

   # now verify
   if {!$fast_setup} {
      set not_set 1 
      foreach filename $value {
         if {$filename == "none"} {
            set not_set 0
         }
      }

      if {$not_set == 1} {
         # make a proper list out of the input
         set new_value ""
         foreach filename $value {
            append new_value " $filename"
         }
         set value [string trim $new_value]

         foreach filename $value {
            # is full path ?
            if {[string first "/" $filename] != 0} {
               puts $CHECK_OUTPUT "File name \"$filename\" doesn't start with \"/\""
               return -1
            }

            # is file ?
            if {[file isfile $filename] != 1} {
               puts $CHECK_OUTPUT "File \"$filename\" not found"
               return -1
            }
         }

         foreach filename $value {

            if { $only_check == 0 } {
               puts $CHECK_OUTPUT "checking configuration:\n\"$filename\""
            }

            # clear previously read config
            if {[info exists add_config]} {
               unset add_config
            }
            # read additional config file
            if {[read_array_from_file $filename "testsuite configuration" add_config] != 0} {
               puts $CHECK_OUTPUT "cannot read configuration file \"$filename\""
               return -1
            }


            #  cell or independed cluster support?
            #  o if cluster have the same cvs source directory AND the same SGE_ROOT the
            #    compilation is done in the main cluster (ts with additional config)
            #
            #  o if SGE_ROOT is different the cvs source has also to be different
            #    (complete independed additional cluster config). Then the compilation
            #    is done via operate_additional_clusters call. This means
            #    gridengine version, and cvs release may be different

            set allow_master_as_execd 1
            if { $add_config(product_root) == $config(product_root) && 
                 $add_config(source_dir)   == $config(source_dir) } {
               if { $only_check == 0 } {
                  puts -nonewline $CHECK_OUTPUT "   (cell cluster) ..."
               }
               # now make sure that the additional configurations can work together
               # the following parameters have to be the same for all configs
               set same_params "gridengine_version source_dir source_cvs_release host_config_file user_config_file product_root testsuite_root_dir product_feature aimk_compile_options dist_install_options qmaster_install_options execd_install_options package_directory package_type"
               # the following parameters have to differ between all configs
               # TODO (Issue #139): remove master_host and execd_hosts from this list if issue #139 is fixed
               set diff_params "results_dir commd_port cell master_host execd_hosts"

               # TODO (Issue #139): also remove this allow_master_as_execd check if issue #139 is fixed
               # since testsuite has problems with shutdown different cell clusters (because of same SGE_ROOT directory)
               # we also don't allow the qmaster host be an exed host in an additional cluster
               set allow_master_as_execd 0
            } else {
               if { $only_check == 0 } {
                  puts -nonewline $CHECK_OUTPUT "   (independent cluster) ..."
               }
               # now make sure that the additional configurations can work together
               # the following parameters have to be the same for all configs
               set same_params "host_config_file user_config_file testsuite_root_dir"
               # the following parameters have to differ between all configs
               set diff_params "results_dir commd_port product_root"
            }

            # clear previously joined_config
            if { [info exists joined_config ] } {
               unset joined_config
            }

            # create joined_config
            foreach param "$same_params $diff_params" {
               set helpval {}
               lappend helpval $config($param) 
               set joined_config($param) $helpval
            }

            # add the params to be checked to our joined config
            foreach param "$same_params $diff_params" {
               set helpval {}
               lappend helpval $add_config($param)
               lappend joined_config($param) $helpval
            }

            # now we check for equality or difference
            foreach param $same_params {
               if {[llength [lsort -unique $joined_config($param)]] != 1} {
                  puts $CHECK_OUTPUT "\nThe parameter \"$param\" has to be the same for configuration\n\"$filename\","
                  puts $CHECK_OUTPUT "but has the following values:\n$joined_config($param)"
                  return -1
               }
            }
            foreach param $diff_params {
               if {[llength [lsort -unique $joined_config($param)]] != 2} {
                  puts $CHECK_OUTPUT "\nThe parameter \"$param\" (=\"$config($param)\") has to be different for configuration\n\"$filename\","
                  puts $CHECK_OUTPUT "but has the following values:\n$joined_config($param)"
                  return -1
               }
               # now if param is a list check content
               if {[llength $add_config($param)] > 1 || [llength $config($param)] > 1} {
                  foreach val $add_config($param) {
                     if { [string first $val $config($param)] >= 0 } {
                        puts $CHECK_OUTPUT "\nFound value \"$val\" of configuration\n\"$filename\"\nin configuration for parameter \"$param\" in testsuite config"
                        return -1
                     }
                  }
               }
            }

            if {$allow_master_as_execd == 0} {
               # since testsuite has problems with shutdown different cell clusters (because of same SGE_ROOT directory)
               # we also don't allow the qmaster host be an exed host in an additional cluster
               if { [string first $config(master_host) $add_config(execd_hosts) ] >= 0 } {
                  puts $CHECK_OUTPUT "\nThe master host ($config(master_host)) of the testsuite configuration"
                  puts $CHECK_OUTPUT "is not a supported cell execd host for config \"$filename\""
                  return -1
               }
            }

            if { $only_check == 0 } {
               puts $CHECK_OUTPUT "ok"
            }
         }
      } else {
         set value "none"
      }
   }

   return $value
}



#****** config/config_results_dir() *********************************************
#  NAME
#     config_results_dir() -- results directory setup
#
#  SYNOPSIS
#     config_results_dir { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_results_dir { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_MAIN_RESULTS_DIR
   global CHECK_PROTOCOL_DIR
   global CHECK_JOB_OUTPUT_DIR
   global CHECK_RESULT_DIR 
   global CHECK_BAD_RESULT_DIR 
   global CHECK_REPORT_FILE 
   global fast_setup


   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
      if { $default_value == "" } {
         set value $config(testsuite_root_dir)/results
      }
   }

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts $CHECK_OUTPUT "Could not get local host name" 
      return -1
   }

   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter the full pathname of the testsuite results directory, or"
      puts $CHECK_OUTPUT "press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "The testsuite will use this directory to save test results and internal"
      puts $CHECK_OUTPUT "data."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value [tail_directory_name $input]
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   # now verify
   if {!$fast_setup} {
      # is full path ?
      if { [ string first "/" $value ] != 0 } {
         puts $CHECK_OUTPUT "Path \"$value\" doesn't start with \"/\""
         return -1
      }

      if { [tail_directory_name $value] != $value } {
         puts $CHECK_OUTPUT "\nPath \"$value\" is not a valid directory name, try \"[tail_directory_name $value]\""
         return -1
      }

      if { [ file isdirectory $value ] != 1 } {
         file mkdir $value
      }

      # is file ?
      if { [ file isdirectory $value ] != 1 } {
         puts $CHECK_OUTPUT "Directory \"$value\" not found"
         return -1
      }
   }

   # set global values
   set CHECK_MAIN_RESULTS_DIR $value
   set CHECK_PROTOCOL_DIR $CHECK_MAIN_RESULTS_DIR/protocols
   set CHECK_JOB_OUTPUT_DIR "$CHECK_MAIN_RESULTS_DIR/testsuite_job_outputs"

   set CHECK_RESULT_DIR "$CHECK_MAIN_RESULTS_DIR/$local_host.completed"
   set CHECK_BAD_RESULT_DIR "$CHECK_MAIN_RESULTS_DIR/$local_host.uncompleted"
   set CHECK_REPORT_FILE "$CHECK_MAIN_RESULTS_DIR/$local_host.report"
 
   if {[file isdirectory "$CHECK_RESULT_DIR"] != 1} {
        file mkdir "$CHECK_RESULT_DIR"
   }
   if {[file isdirectory "$CHECK_BAD_RESULT_DIR"] != 1} {
        file mkdir "$CHECK_BAD_RESULT_DIR"
   }
   if {[file isdirectory "$CHECK_JOB_OUTPUT_DIR"] != 1} {
        file mkdir "$CHECK_JOB_OUTPUT_DIR"
   }
   return $value
}

#****** config/config_connection_type() *************************************************
#  NAME
#     config_connection_type() -- configurate the remote connect starter
#
#  SYNOPSIS
#     config_connection_type { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_connection_type {only_check name config_array} {
   global CHECK_OUTPUT 
   global CHECK_USER
   global fast_setup
   global have_ssh_access_state

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if {$actual_value == ""} {
      set value $default_value
   }

   if {$only_check == 0} {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter"
      puts $CHECK_OUTPUT "   - \"ssh\" if testsuite should use secure shell without passwords"
      puts $CHECK_OUTPUT "   - \"ssh_with_password\" if testsuite should use secure shell with passwords"
      puts $CHECK_OUTPUT "   - \"rlogin\" if testsuite should use rlogin"
      puts $CHECK_OUTPUT "to connect to the cluster hosts"
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [wait_for_enter 1]
      if { [string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
      # reset global variable for have_ssh_access()
      # procedure !!
      set have_ssh_access_state -1 
   }

   if {$value != "ssh" && $value != "ssh_with_password"
       && $value != "rlogin"} {
       return -1
   }

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts $CHECK_OUTPUT "Could not get local host name" 
      return -1
   }

   if {!$fast_setup} {
      set result [start_remote_prog $local_host $CHECK_USER "echo" "\"hello $local_host\"" prg_exit_state 60 0 "" "" 1 0]
      if { $prg_exit_state != 0 } {
         puts $CHECK_OUTPUT "rlogin/ssh to host $local_host doesn't work correctly"
         return -1
      }
      if { [ string first "hello $local_host" $result ] < 0 } {
         puts $CHECK_OUTPUT "$result"
         puts $CHECK_OUTPUT "echo \"hello $local_host\" doesn't work"
         return -1
      }
   }

   return $value
}


#****** config/config_source_dir() **********************************************
#  NAME
#     config_source_dir() -- source directory setup
#
#  SYNOPSIS
#     config_source_dir { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_source_dir { only_check name config_array } {
   global CHECK_OUTPUT 
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
      if { $default_value == "" } {
         set pos [string first "/testsuite" $config(testsuite_root_dir)]
         set value [string range $config(testsuite_root_dir) 0 $pos]
         append value "source"
      }
   }
   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter the full pathname of the Grid Engine source directory, or"
      puts $CHECK_OUTPUT "press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "The testsuite needs this directory to call aimk (to compile source code)"
      puts $CHECK_OUTPUT "and for resolving the host names (util scripts)."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value [tail_directory_name $input]
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   # now verify
   if {!$fast_setup} {
      # is full path ?
      if { [ string first "/" $value ] != 0 } {
         puts $CHECK_OUTPUT "Path \"$value\" doesn't start with \"/\""
         return -1
      }
 
      if { [tail_directory_name $value] != $value } {
         puts $CHECK_OUTPUT "\nPath \"$value\" is not a valid directory name, try \"[tail_directory_name $value]\""
         return -1
      }

      # is directory ?
      if { [ file isdirectory $value ] != 1 } {
         puts $CHECK_OUTPUT "Directory \"$value\" not found"
         return -1
      }

      # is aimk file present ?
      if { [ file isfile $value/aimk ] != 1 } {
         puts $CHECK_OUTPUT "File \"$value/aimk\" not found"
         return -1
      }
   }
 
   set local_arch [ resolve_arch "none" 1 $value]
   if { $local_arch == "unknown" } {
      puts $CHECK_OUTPUT "Could not resolve local system architecture" 
      return -1
   }
   return $value
}

#****** config/config_source_cvs_hostname() *************************************
#  NAME
#     config_source_cvs_hostname() -- cvs hostname setup
#
#  SYNOPSIS
#     config_source_cvs_hostname { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_source_cvs_hostname { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_USER 
   global fast_setup

   upvar $config_array config

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts $CHECK_OUTPUT "Could not get local host name" 
      return -1
   }

   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
      if { $default_value == "" } {
         set value $local_host
      }
   }
   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter the name of the host used for executing cvs commands"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   if {!$fast_setup} {
      set host $value
      set result [start_remote_prog $host $CHECK_USER "echo" "\"hello $host\"" prg_exit_state 60 0 "" "" 1 0]
      if { $prg_exit_state != 0 } {
         puts $CHECK_OUTPUT "rlogin to host $host doesn't work correctly"
         return -1
      }
      if { [ string first "hello $host" $result ] < 0 } {
         puts $CHECK_OUTPUT "$result"
         puts $CHECK_OUTPUT "echo \"hello $host\" doesn't work"
         return -1
      }
      set result [start_remote_prog $host $CHECK_USER "which" "cvs" prg_exit_state 60 0 "" "" 1 0]
      if { $prg_exit_state != 0 } {
         puts $CHECK_OUTPUT $result
         puts $CHECK_OUTPUT "cvs not found on host $host. Please enhance your PATH envirnoment"
         return -1
      } else {
         debug_puts $result
         debug_puts "found cvs command"
      }
   }
   return $value
}

#****** config/config_source_cvs_release() **************************************
#  NAME
#     config_source_cvs_release() -- cvs release setup
#
#  SYNOPSIS
#     config_source_cvs_release { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_source_cvs_release {only_check name config_array} {
   global CHECK_OUTPUT 
   global CHECK_USER 
   global fast_setup

   upvar $config_array config

   # fix "maintrunc" typo - it will be written the next time the config is modified
   if {$config($name) == "maintrunc"} {
      set config($name) "maintrunk"
   }

   if {![file isdirectory $config(source_dir)]} {
      puts $CHECK_OUTPUT "source directory $config(source_dir) doesn't exist"
      return -1
   }
   
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if {$actual_value == ""} {
      set value $default_value
      if {$default_value == ""} {
         set result [start_remote_prog $config(source_cvs_hostname) $CHECK_USER "cat" "$config(source_dir)/CVS/Tag" prg_exit_state 60 0 "" "" 1 0]
         set result [string trim $result]
         if {$prg_exit_state == 0} {
            if {[string first "T" $result] == 0} {
               set value [string range $result 1 end]
            }
         } else {
            set value "maintrunk" 
         }
      }
   }
   if {$only_check == 0} {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter cvs release tag (\"maintrunk\" specifies no tag)"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [wait_for_enter 1]
      if {[string length $input] > 0} {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   if {!$fast_setup} {
      set result [start_remote_prog $config(source_cvs_hostname) $CHECK_USER "cat" "$config(source_dir)/CVS/Tag" prg_exit_state 60 0 "" "" 1 0]
      set result [string trim $result]
      if {$prg_exit_state == 0} {
         if {[string compare $result "T$value"] != 0 && [string compare $result "N$value"] != 0} {
            puts $CHECK_OUTPUT "CVS/Tag entry doesn't match cvs release tag \"$value\" in directory $config(source_cvs_hostname)"
            return -1
         }
      }
   }
   return $value
}


#****** config/config_host_config_file() ****************************************
#  NAME
#     config_host_config_file() -- host config file setup
#
#  SYNOPSIS
#     config_host_config_file { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_host_config_file { only_check name config_array } {
   global CHECK_OUTPUT
   global fast_setup

   upvar $config_array config
   
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter the full pathname of the host configuration file, or press >RETURN<"
      puts $CHECK_OUTPUT "to use the default value."
      puts $CHECK_OUTPUT "The host configuration file is used to define the cluster hosts setup"
      puts $CHECK_OUTPUT "configuration needed by the testsuite."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   # now verify
   set hconfdone 0
   if {!$fast_setup} {
      # is full path ?
      if { [ string first "/" $value ] != 0 } {
         puts $CHECK_OUTPUT "Path \"$value\" doesn't start with \"/\""
         return -1
      }

      # is file ?
      if { [ file isfile $value ] != 1 && $only_check != 0 } {
         if { $only_check != 0 } {
            puts $CHECK_OUTPUT "File \"$value\" not found"
            return -1
         } else {
            setup_host_config $value
            set hconfdone 1 
         }
      }
   }
 
   if { $hconfdone == 0} {
      setup_host_config $value
   }
  
   return $value
}

#****** config/config_user_config_file() ****************************************
#  NAME
#     config_user_config_file() -- user configuration file setup
#
#  SYNOPSIS
#     config_user_config_file { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_user_config_file { only_check name config_array } {
   global CHECK_OUTPUT
   global fast_setup

   upvar $config_array config
   
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
   }
   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter the full pathname of the user configuration file, or press >RETURN<"
      puts $CHECK_OUTPUT "to use the default value."
      puts $CHECK_OUTPUT "The user configuration file is used to define the cluster user needed by the"
      puts $CHECK_OUTPUT "testsuite."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   # now verify
   set userconfdone 0
   if {!$fast_setup} {
      # is full path ?
      if { [ string first "/" $value ] != 0 } {
         puts $CHECK_OUTPUT "Path \"$value\" doesn't start with \"/\""
         return -1
      }

      # is file ?
      if { [ file isfile $value ] != 1 && $only_check != 0 } {
         if { $only_check != 0 } {
            puts $CHECK_OUTPUT "File \"$value\" not found"
            return -1
         } else {
            setup_user_config $value
            set userconfdone 1 
         }
      }
   }
 
   if { $userconfdone == 0} {
      setup_user_config $value
   }
  
   return $value
}

#****** config/config_db_config_file() *****************************************
#  NAME
#     config_db_config_file() -- database configuration file setup
#
#  SYNOPSIS
#     config_db_config_file { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_db_config_file { only_check name config_array } {
   global fast_setup

   upvar $config_array config
   
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
      if { $default_value == "" } { 
         set value "none"
      }
   }

   if { $only_check == 0 } {
      # do setup  
      puts "" 
      puts "Please enter the full pathname of the database configuration file, or press >RETURN< "
      puts "to use the default value."
      puts "The database configuration file is used to define the cluster database needed "
      puts "for the ARCo testsuite, therefore this parameter is mandatory for ARCo tests. "
      puts "(default: $value)"
      puts -nonewline "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts "using default value"
      }
   } 

   # now verify
   if {!$fast_setup} {

      # must be set if checktree_arco is set
      if { [string compare $value "none"] == 0 } {
         if { $config(additional_checktree_dirs) != "none" } {
            foreach dir $config(additional_checktree_dirs) {
               if { [string match "*checktree_arco" $dir] == 1 } {
                  puts "\nThe path to database configuration file must be set."
                  return -1
               }
            }
         }

      } else {
         set dbconfdone 0
         # is full path ?
         if { [ string first "/" $value ] != 0 } {
            puts "Path \"$value\" doesn't start with \"/\""
            return -1
         }

         # is file ?
         if { [ file isfile $value ] != 1 && $only_check != 0 } {
            if { $only_check != 0 } {
               puts "File \"$value\" not found"
               return -1
            } else {
               setup_db_config $value
               set dbconfdone 1 
            }
         }

         if { $dbconfdone == 0} {
            setup_db_config $value
         }

      }
   }

   return $value
}

#****** config/config_master_host() *********************************************
#  NAME
#     config_master_host() -- master host setup
#
#  SYNOPSIS
#     config_master_host { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_master_host { only_check name config_array } {
   global CHECK_OUTPUT 
   global ts_host_config do_nomain
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts $CHECK_OUTPUT "Could not get local host name" 
      return -1
   }

   if {$actual_value == ""} {
      set value $default_value
      if {$default_value == ""} {
         set value $local_host
      }
   }

   # master host must be check_host !!!
   if {$only_check == 0} {
      config_select_host $value config
      puts $CHECK_OUTPUT "Press enter to use host \"$value\" as qmaster host"
      wait_for_enter
      set value $local_host
   } 

   if {!$fast_setup} {
      debug_puts "master host: $value"
      if {[string compare $value $local_host] != 0 && $do_nomain == 0} {
         puts $CHECK_OUTPUT "Master host must be local host"
         return -1
      }

      if {[llength $value] != 1} {
         puts $CHECK_OUTPUT "qmaster_host has more than one hostname entry"
         return -1
      }

      # Verify that the master host is configured in host config and
      # supported with the configured Grid Engine version.
      if {![host_conf_is_supported_host $value]} {
         return -1
      }

      if {[compile_check_compile_hosts $value] != 0} {
         return -1
      }
   }


   return $value
}

#****** config/config_execd_hosts() *********************************************
#  NAME
#     config_execd_hosts() -- execd daemon host setup
#
#  SYNOPSIS
#     config_execd_hosts { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_execd_hosts { only_check name config_array } {
   global CHECK_OUTPUT do_nomain
   global ts_host_config fast_setup

   upvar $config_array config
   
   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts $CHECK_OUTPUT "Could not get local host name" 
      return -1
   }
   set value $config($name)

   if {$only_check == 0} {
      # initialize value from defaults, if not yet set
      if {$value == ""} {
         set value $config($name,default)
         if {$value == ""} {
            set value $local_host
         }
      }

      # edit the execd host list, check_host must be first host
      set value [config_select_host_list config $name $value]
      set value [config_check_host_in_hostlist $value]
   }

   if {!$fast_setup} {
      if {![config_verify_hostlist $value "execd" 1]} {
         return -1
      }
   }

   # set host lists
   # we need a mapping from node to physical hosts
   foreach host $value {
      node_set_host $host $host
      set nodes [host_conf_get_nodes $host]
      foreach node $nodes {
         node_set_host $node $host
      }
   }

   # create list of all (execd) nodes
   set config(all_nodes) [host_conf_get_all_nodes $value]
   set config(execd_nodes) [host_conf_get_nodes $value]

   # create a list of unique nodes (one node per physical host)
   set config(unique_execd_nodes) [host_conf_get_unique_nodes $value]

   # create a list of nodes unique per architecture
   set config(unique_arch_nodes) [host_conf_get_unique_arch_nodes $config(unique_execd_nodes)]

   # now sort these lists for convenience
   set config(all_nodes) [lsort -dictionary $config(all_nodes)]
   set config(execd_nodes) [lsort -dictionary $config(execd_nodes)]
   set config(unique_execd_nodes) [lsort -dictionary $config(unique_execd_nodes)]
   set config(unique_arch_nodes) [lsort -dictionary $config(unique_arch_nodes)]

   return $value
}


#****** config/config_submit_only_hosts() ***************************************
#  NAME
#     config_submit_only_hosts() -- submit only hosts setup
#
#  SYNOPSIS
#     config_submit_only_hosts { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_submit_only_hosts { only_check name config_array } {
   global CHECK_OUTPUT 
   global ts_host_config fast_setup

   upvar $config_array config
   set value $config($name)

   if { $only_check == 0 } {
      # initialize value from defaults, if not yet set
      if {$value == ""} {
         set value $config($name,default)
      }

      if {$value == "none"} {
         set value ""
      }

      # edit the submit only host list
      set value [config_select_host_list config $name $value]

      if {$value == ""} {
         set value "none"
      }
   } 

   if {$value != "none"} {
      if {!$fast_setup} {
         if {![config_verify_hostlist $value "submit only" 0]} {
            return -1
         }

         # a submit only host may not be used otherwise in the cluster
         set exclude "$config(master_host) $config(shadowd_hosts) $config(execd_hosts)"
         set exclude [lsort -unique $exclude]

         foreach host $value {
            if {[lsearch $exclude $host] >= 0} {
               puts $CHECK_OUTPUT "Submit only host $host is used as admin/exec host in the cluster"
               return -1
            }
         }
      }
   }
   return $value
}

#****** config/config_generic_port() **********************************************
#  NAME
#     config_generic_port() -- generic port setip
#
#  SYNOPSIS
#     config_generic_port { only_check name config_array } 
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#     helptext     - helptext list (one line per enty)
#     port_type    - list of port type specifiers. The following
#                    values are allowed 
#                        only_even       => allow only even ports
#                        only_reserved   => allows only port < 1024
#                        allow_null_port => the value 0 is for the port allowed
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_generic_port { only_check name config_array helptext { port_type {} } } {
   global CHECK_OUTPUT 
   global CHECK_COMMD_PORT
   global CHECK_USER
   global ts_user_config fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
#     # do setup  
      puts $CHECK_OUTPUT ""
      foreach line $helptext {
         puts $CHECK_OUTPUT $line
      }
      puts $CHECK_OUTPUT "(default: $value)"
      set ok 0
      while { $ok == 0 } {
         puts -nonewline $CHECK_OUTPUT "> "
         set input [ wait_for_enter 1]
         if {[string length $input] == 0 } {
            puts $CHECK_OUTPUT "using default value"
            set ok 1
         } elseif {[lsearch $port_type "only_even"] >= 0 && [ expr ( $input % 2 ) ] != 0 } {
            puts $CHECK_OUTPUT "value is not even"
            set ok 0
         } elseif {[lsearch $port_type "allow_null_port"] < 0 && $input == 0} {
            puts $CHECK_OUTPUT "0 is not a valid value for a port"
            set ok 0
         } else {
            set value $input
            set ok 1
         }
      }

      set add_port 0 
      if { $value > 0 } {
         if { [ info exists ts_user_config($CHECK_USER,portlist) ] != 1 } {
            puts $CHECK_OUTPUT "No portlist defined for user $CHECK_USER in user configuration"
            puts $CHECK_OUTPUT "Press enter to add user $CHECK_USER"
            wait_for_enter
            set errors 0
            incr errors [user_config_userlist_add_user ts_user_config  $CHECK_USER]
            incr errors [user_config_userlist_edit_user ts_user_config $CHECK_USER]
            incr errors [save_user_configuration $config(user_config_file)]
            if { $errors != 0 } {
               puts $CHECK_OUTPUT "Errors press enter to edit user configuration"
               wait_for_enter
               setup_user_config $config(user_config_file) 1
            }
         }
         # Users reserve allways a port tuple
         # master_port and execd_port
         if { [expr $value % 2] != 0 } {
            set master_port [expr $value - 1]
            set execd_port $value
         } else {
            set master_port $value
            set execd_port  [expr $value + 1]
         }
         
         if { [ lsearch $ts_user_config($CHECK_USER,portlist) $master_port ] < 0 } {
            puts $CHECK_OUTPUT "ports ${master_port} - ${execd_port} not defined for user $CHECK_USER"
            puts $CHECK_OUTPUT "Press enter to add ports ${master_port} - ${execd_port}"
            wait_for_enter
            set errors 0
            set new_value "$ts_user_config($CHECK_USER,portlist) $master_port"
            incr errors [user_config_userlist_set_portlist ts_user_config $CHECK_USER $new_value]
            if { $errors == 0 }  {
               incr errors [save_user_configuration $config(user_config_file)]
            }
            if { $errors != 0 } {
               puts $CHECK_OUTPUT "Errors press enter to edit user configuration"
               wait_for_enter
               setup_user_config $config(user_config_file) 1
            }
         }
      }
   }

   if {!$fast_setup} {
      if { [lsearch $port_type "allow_null_port"] < 0 && $value < 1  } {
         puts $CHECK_OUTPUT "Port $value is < 1"
         return -1;
      }
      if {$value > 0} {
         if { [ info exists ts_user_config($CHECK_USER,portlist) ] != 1 } {
            puts $CHECK_OUTPUT "User $CHECK_USER has not portlist entry in user configuration"
            return -1
         }
         if { [expr $value % 2] != 0 } {
            set master_port [expr $value - 1]
            set execd_port $value
         } else {
            set master_port $value
            set execd_port  [expr $value + 1]
         }
         if { [ lsearch $ts_user_config($CHECK_USER,portlist) $master_port] < 0 } {
            puts $CHECK_OUTPUT "Port $value not in portlist of user $CHECK_USER" 
            return -1
         }
      }

      if { [lsearch $port_type "only_even"] >= 0 && [ expr ( $value % 2 ) ] == 1 } {
         puts $CHECK_OUTPUT "Port $value is not even"
         return -1;
      }
      
      if { [lsearch $port_type "only_reserved"] >= 0 && $value >= 1024 } {
         puts $CHECK_OUTPUT "Port $value is >= 1024"
         return -1;
      }

      if { $value > 65000 } {
         puts $CHECK_OUTPUT "Port $value is > 65000"
         return -1;
      }
   }
   return $value
}


#****** config/config_commd_port() **********************************************
#  NAME
#     config_commd_port() -- commd port option setup
#
#  SYNOPSIS
#     config_commd_port { only_check name config_array } 
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_commd_port { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_COMMD_PORT
   global CHECK_USER
   global ts_user_config fast_setup

   upvar $config_array config
   
   set helptext {
      "Please enter the port number value the testsuite should use for COMMD_PORT,"
      "or press >RETURN< to use the default value."
      ""
      "(IMPORTANT NOTE: COMMD_PORT must be a even number, because for"
      "SGE/EE 6.0 sytems or later COMMD_PORT is used for SGE_QMASTER_PORT and"
      "COMMD_PORT + 1 is used for SGE_EXECD_PORT)"
   }   
   set value [config_generic_port $only_check $name config $helptext {"only_even"}]

   if { $value > 0 } { 
      set CHECK_COMMD_PORT $value
   }

   return $value
}

#****** config/config_jmx_port() **********************************************
#  NAME
#     config_jmx_port() -- jmx port option setup
#
#  SYNOPSIS
#     config_jmx_port { only_check name config_array } 
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_jmx_port { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_COMMD_PORT
   global CHECK_USER
   global ts_user_config fast_setup

   upvar $config_array config
   
   set helptext {
      "Please enter the port number for qmaster JMX mbean server"
      "or press >RETURN< to use the default value."
      ""
      "value 0 means that the mbean server is not started"
   }   
   set value [config_generic_port $only_check $name config $helptext { "allow_null_port" }]

   return $value
}

#****** config/config_jmx_ssl() **********************************************
#  NAME
#     config_jmx_ssl() -- jmx ssl server authentication option setup
#
#  SYNOPSIS
#     config_jmx_ssl { only_check name config_array } 
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_jmx_ssl { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_COMMD_PORT
   global CHECK_USER
   global ts_user_config fast_setup

   upvar $config_array config
   
   set helptext {
      "Please enter true to enable SSL server authentication for qmaster JMX mbean server"
      "or press >RETURN< to use the default value."
   }   
   set value [config_generic $only_check $name config $helptext "boolean" ] 

   return $value
}

#****** config/config_jmx_ssl_client() **********************************************
#  NAME
#     config_jmx_ssl_client() -- jmx ssl client authentication option setup
#
#  SYNOPSIS
#     config_jmx_ssl_client { only_check name config_array } 
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_jmx_ssl_client { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_COMMD_PORT
   global CHECK_USER
   global ts_user_config fast_setup

   upvar $config_array config
   
   set helptext {
      "Please enter true to enable SSL client authentication for qmaster JMX mbean server"
      "or press >RETURN< to use the default value."
   }   
   set value [config_generic $only_check $name config $helptext "boolean"] 

   return $value
}

#****** config/config_jmx_ssl_keystore_pw() **********************************************
#  NAME
#     config_jmx_ssl_keystore_pw() -- jmx ssl keystore password
#
#  SYNOPSIS
#     config_jmx_ssl_keystore_pw { only_check name config_array } 
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_jmx_ssl_keystore_pw { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_COMMD_PORT
   global CHECK_USER
   global ts_user_config fast_setup

   upvar $config_array config
   
   set helptext {
      "Please enter the JMX SSL keystore pw for qmaster JMX mbean server"
      "or press >RETURN< to use the default value."
   }   
   set value [config_generic $only_check $name config $helptext "string"] 

   return $value
}

#****** config/config_reserved_port() **********************************************
#  NAME
#     config_reserved_port() -- reserved option setup
#
#  SYNOPSIS
#     config_reserved_port { only_check name config_array } 
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_reserved_port { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_COMMD_PORT
   global CHECK_USER
   global ts_user_config fast_setup

   upvar $config_array config
   
   set helptext {
      "Please enter an unused port number < 1024. This port is used to test"
      "port binding." 
      "or press >RETURN< to use the default value."
   }
   
   set value [config_generic_port $only_check $name config $helptext { "only_reserved" }]

   return $value
}


#****** config/config_product_root() ********************************************
#  NAME
#     config_product_root() -- product root setup
#
#  SYNOPSIS
#     config_product_root { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_product_root { only_check name config_array } {
   global CHECK_OUTPUT 
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
#     # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter the path where the testsuite should install Grid Engine,"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "You can also specify a current installed Grid Engine system path."
      puts $CHECK_OUTPUT "WARNING: The compile option will remove the content of this directory"
      puts $CHECK_OUTPUT "or store it to \"testsuite_trash\" directory with testsuite_trash commandline option!!!"
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value [tail_directory_name $input]
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   if {!$fast_setup} {

      if { [tail_directory_name $value] != $value } {
         puts $CHECK_OUTPUT "\nPath \"$value\" is not a valid directory name, try \"[tail_directory_name $value]\""
         return -1
      }

      # is full path ?
      if { [ string first "/" $value ] != 0 } {
         puts $CHECK_OUTPUT "Path \"$value\" doesn't start with \"/\""
         return -1
      }

      if { [ file isdirectory $value ] != 1 } {
         puts $CHECK_OUTPUT "Creating directory:\n$value"
         file mkdir $value
      }

      if { [ file isdirectory $value ] != 1 } {
         puts $CHECK_OUTPUT "Directory \"$value\" not found"
         return -1
      }

      set path_length [ string length "/bin/sol-sparc64/sge_qmaster" ]
      if { [string length "$value/bin/sol-sparc64/sge_qmaster"] > 60 } {
           puts $CHECK_OUTPUT "path for product_root_directory is too long (must be <= [expr ( 60 - $path_length )] chars)"
           puts $CHECK_OUTPUT "The testsuite tries to find processes via ps output most ps output is truncated"
           puts $CHECK_OUTPUT "for longer lines."
           return -1
      }
   }

   return $value
}



#****** config/config_product_type() ********************************************
#  NAME
#     config_product_type() -- product type setup
#
#  SYNOPSIS
#     config_product_type { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_product_type { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_PRODUCT_TYPE
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
#     # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please specify the product type. Enter \"sge\" for Grid Engine,"
      puts $CHECK_OUTPUT "\"sgeee\" for Grid Engine Enterprise Edition"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   }

   if {!$fast_setup} {
      if {    ([string compare "sgeee" $value ] != 0) &&
              ([string compare "sge"   $value ] != 0) } {
           puts $CHECK_OUTPUT "product_type can only be \"sge\" or \"sgeee\""
           return -1
      }

      if {$config(gridengine_version) >= 60 && $value == "sge"} {
           puts $CHECK_OUTPUT "product_type can only be \"sgeee\" for Grid Engine 6.0 or higher"
           return -1
      }
   }
  
   set CHECK_PRODUCT_TYPE $value

   return $value
}

#****** config/config_product_feature() *****************************************
#  NAME
#     config_product_feature() -- product feature setup
#
#  SYNOPSIS
#     config_product_feature { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_product_feature { only_check name config_array } {
   global ts_config
   global CHECK_OUTPUT
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
#     # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please specify the product feature."
      puts $CHECK_OUTPUT "Enter \"none\" for no special product features."
      puts $CHECK_OUTPUT "Enter \"csp\" for Certificate Security Protocol"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   if {!$fast_setup} {
      if { ([string compare "none"   $value ] != 0) &&
           ([string compare "csp" $value ] != 0) } {
           puts $CHECK_OUTPUT "product_feature can only be \"none\" or \"csp\""
           return -1
      }
   }

   return $value
}

#****** config/config_aimk_compile_options() ************************************
#  NAME
#     config_aimk_compile_options() -- aimk compile option setup
#
#  SYNOPSIS
#     config_aimk_compile_options { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_aimk_compile_options { only_check name config_array } {
   global CHECK_OUTPUT 
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
   }
   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter aimk compile options (use \"none\" for no options)"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   return $value
}


#****** config/config_dist_install_options() ************************************
#  NAME
#     config_dist_install_options() -- distrib install options
#
#  SYNOPSIS
#     config_dist_install_options { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_dist_install_options { only_check name config_array } {
   global CHECK_OUTPUT 
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter dist install options (use \"none\" for no options)"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   }

   # set global values
   return $value
}

#****** config/config_qmaster_install_options() *********************************
#  NAME
#     config_qmaster_install_options() -- master install options setup
#
#  SYNOPSIS
#     config_qmaster_install_options { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_qmaster_install_options { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_QMASTER_INSTALL_OPTIONS
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter Grid Engine qmaster install options (use \"none\" for no options)"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   }

   # set global values
   set CHECK_QMASTER_INSTALL_OPTIONS  $value
   if { [ string compare "none" $value ] == 0  } {
      set CHECK_QMASTER_INSTALL_OPTIONS  ""
   }

   return $value
}

#****** config/config_execd_install_options() ***********************************
#  NAME
#     config_execd_install_options() -- install options setup
#
#  SYNOPSIS
#     config_execd_install_options { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_execd_install_options { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_EXECD_INSTALL_OPTIONS 
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter Grid Engine execd install options (use \"none\" for no options)"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   }

   # set global values
   set CHECK_EXECD_INSTALL_OPTIONS   $value
   if { [ string compare "none" $value ] == 0  } {
      set CHECK_EXECD_INSTALL_OPTIONS  ""
   }

   return $value
}


#****** config/config_package_directory() ***************************************
#  NAME
#     config_package_directory() -- package optiont setup
#
#  SYNOPSIS
#     config_package_directory { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#
#*******************************************************************************
proc config_package_directory { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_PACKAGE_DIRECTORY CHECK_PACKAGE_TYPE
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter directory path to Grid Engine packages (pkgadd or zip),"
      puts $CHECK_OUTPUT "(use \"none\" if there are no packages available)"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         if { [string compare "none" $input ] != 0 } {
            # only tail to directory name when != "none"
            set value [tail_directory_name $input]
         } else {
            # we don't have a directory
            set value $input 
         }
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   # package dir configured?
   if {!$fast_setup} {
      if { [string compare "none" $value ] != 0 } {

         if { [tail_directory_name $value] != $value } {
            puts $CHECK_OUTPUT "\nPath \"$value\" is not a valid directory name, try \"[tail_directory_name $value]\""
            return -1
         }

         # directory doesn't exist? If we shall generate packages, create dir
         if { ![file isdirectory $value] } {
            if { $config(package_type) == "create_tar" } {
               file mkdir $value
            } else {
               puts $CHECK_OUTPUT "Directory \"$value\" not found"
               return -1
            }
         }
         if { [string compare $config(package_type) "tar"] == 0 }    {
            if { [check_packages_directory $value check_tar] != 0 } {
               puts $CHECK_OUTPUT "error checking package_directory! are all package file installed?"
               return -1
            }
         } else {
            if { [string compare $config(package_type) "tar"] == 0 }    {
               if { [check_packages_directory $value check_zip] != 0 } {
                  puts $CHECK_OUTPUT "error checking package_directory! are all package file installed?"
                  return -1
               }
            }
         }
      }
   }

   # set global values
   set CHECK_PACKAGE_DIRECTORY $value

   return $value
}


#****** config/config_package_type() ********************************************
#  NAME
#     config_package_type() -- package type setup
#
#  SYNOPSIS
#     config_package_type { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_package_type { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_PACKAGE_TYPE
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter package type to test:"
      puts $CHECK_OUTPUT "  \"tar\" to use precompiled tar packages" 
      puts $CHECK_OUTPUT "  \"zip\" to use precompiled sunpkg packages"
      puts $CHECK_OUTPUT "  \"create_tar\" to generate tar packages"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   if {!$fast_setup} {
      if { [string compare "tar" $value ] != 0 && 
           [string compare "zip" $value ] != 0 &&
           [string compare "create_tar" $value ] != 0 } {
         puts $CHECK_OUTPUT "unexpected package type: \"$value\"!"
         return -1
      }
   }

   # set global values
   set CHECK_PACKAGE_TYPE $value

   return $value
}



#****** config/config_dns_domain() **********************************************
#  NAME
#     config_dns_domain() -- dns domain setup
#
#  SYNOPSIS
#     config_dns_domain { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_dns_domain { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_DNS_DOMAINNAME
   global CHECK_USER
   global fast_setup

   upvar $config_array config

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts $CHECK_OUTPUT "Could not get local host name" 
      return -1
   }

   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter your DNS domain name or"
      puts $CHECK_OUTPUT "press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "The DNS domain is used in the qmaster complex test."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   if {!$fast_setup} {
      set result [start_remote_prog $local_host $CHECK_USER "echo" "\"hello $local_host\"" prg_exit_state 60 0 "" "" 1 0]
      if { $prg_exit_state != 0 } {
         puts $CHECK_OUTPUT "rlogin to host $local_host doesn't work correctly"
         return -1
      }
      if { [ string first "hello $local_host" $result ] < 0 } {
         puts $CHECK_OUTPUT "$result"
         puts $CHECK_OUTPUT "echo \"hello $local_host\" doesn't work"
         return -1
      }

      debug_puts "domain check ..."
      set host "$local_host.$value"
      debug_puts "hostname with dns domain: \"$host\""

      set result [start_remote_prog $host $CHECK_USER "echo" "\"hello $host\"" prg_exit_state 60 0 "" "" 1 0]
      if { $prg_exit_state != 0 } {
         puts $CHECK_OUTPUT "rlogin to host $host doesn't work correctly"
         return -1
      }
      if { [ string first "hello $host" $result ] < 0 } {
         puts $CHECK_OUTPUT "$result"
         puts $CHECK_OUTPUT "echo \"hello $host\" doesn't work"
         return -1
      }
   }

   # set global values
   set CHECK_DNS_DOMAINNAME $value

   return $value
}


#****** config/config_dns_for_install_script() **********************************
#  NAME
#     config_dns_for_install_script() -- domain used for sge installation
#
#  SYNOPSIS
#     config_dns_for_install_script { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_dns_for_install_script { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_DEFAULT_DOMAIN
   global CHECK_USER
   global fast_setup

   upvar $config_array config

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts $CHECK_OUTPUT "Could not get local host name" 
      return -1
   }

   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter the DNS domain name used for installation script"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "Set this value to \"none\" if all your cluster hosts are in the"
      puts $CHECK_OUTPUT "same DNS domain."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   if {!$fast_setup} {
      # only check domain if not none
      if { [string compare "none" $value] != 0 } {

         debug_puts "domain check ..."
         set host "$local_host.$value"
         debug_puts "hostname with dns domain: \"$host\""
      
         set result [start_remote_prog $host $CHECK_USER "echo" "\"hello $host\"" prg_exit_state 60 0 "" "" 1 0]
         if { $prg_exit_state != 0 } {
            puts $CHECK_OUTPUT "rlogin to host $host doesn't work correctly"
            return -1
         }
         if { [ string first "hello $host" $result ] < 0 } {
            puts $CHECK_OUTPUT "$result"
            puts $CHECK_OUTPUT "echo \"hello $host\" doesn't work"
            return -1
         }
      }
   }

   # set global values
   set CHECK_DEFAULT_DOMAIN $value

   return $value
}


#****** config/config_mail_application() ***************************************
#  NAME
#     config_mail_application() -- ??? 
#
#  SYNOPSIS
#     config_mail_application { only_check name config_array } 
#
#  FUNCTION
#     ??? 
#
#  INPUTS
#     only_check   - ??? 
#     name         - ??? 
#     config_array - ??? 
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_mail_application { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_USER 
   global CHECK_MAILX_HOST
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter the name of the mail application used for sending"
      puts $CHECK_OUTPUT "e-mails to the testsuite starter. The testsuite supports"
      puts $CHECK_OUTPUT "mailx, sendmail and a path to a mail script. (see mail_application.sh"
      puts $CHECK_OUTPUT "in testsuite/scripts directory for a mail wrapper script template)\n"
      puts $CHECK_OUTPUT "Press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   }

   return $value
}


#****** config/config_mailx_host() **********************************************
#  NAME
#     config_mailx_host() -- mailx option setup
#
#  SYNOPSIS
#     config_mailx_host { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_mailx_host { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_USER 
   global CHECK_MAILX_HOST
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts $CHECK_OUTPUT "Could not get local host name" 
      return -1
   }

   if { $actual_value == "" } {
      set value $default_value
      if { $default_value == "" } {
         set value $local_host
      }
   }
   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter the name of the host used for sending e-mail reports"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "Set this value to \"none\" if you don't want get e-mails from the"
      puts $CHECK_OUTPUT "testsuite."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   if {!$fast_setup} {
      # only check domain if not none
      if { [string compare "none" $value] != 0 } {
         set host $value
         set result [start_remote_prog $host $CHECK_USER "echo" "\"hello $host\"" prg_exit_state 60 0 "" "" 1 0]
         if { $prg_exit_state != 0 } {
            puts $CHECK_OUTPUT "rlogin to host $host doesn't work correctly"
            return -1
         }
         if { [ string first "hello $host" $result ] < 0 } {
            puts $CHECK_OUTPUT "$result"
            puts $CHECK_OUTPUT "echo \"hello $host\" doesn't work"
            return -1
         }
         set result [start_remote_prog $host $CHECK_USER "which" $config(mail_application) prg_exit_state 60 0 "" "" 1 0]
         if { $prg_exit_state != 0 } {
            puts $CHECK_OUTPUT $result
            puts $CHECK_OUTPUT "$config(mail_application) not found on host $host. Please enhance your PATH envirnoment"
            puts $CHECK_OUTPUT "or setup your mail application correctly."
            return -1
         } else {
            debug_puts $result
            debug_puts "found $config(mail_application)"
         }
      }
   }

   # set global values
   set CHECK_MAILX_HOST $value

   return $value
}


#****** config/config_report_mail_to() ******************************************
#  NAME
#     config_report_mail_to() -- mail to setup
#
#  SYNOPSIS
#     config_report_mail_to { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_report_mail_to { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_USER 
   global CHECK_MAILX_HOST
   global CHECK_REPORT_EMAIL_TO
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
      if { $config(mailx_host) == "none" } {
         set value "none"
         set only_check 1
      }
   }

   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter e-mail address where the testsuite should send report mails"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "Set this value to \"none\" if you don't want get e-mails from the"
      puts $CHECK_OUTPUT "testsuite."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   # set global values
   set CHECK_REPORT_EMAIL_TO $value

   return $value
}


#****** config/config_report_mail_cc() ******************************************
#  NAME
#     config_report_mail_cc() -- mail cc setup
#
#  SYNOPSIS
#     config_report_mail_cc { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_report_mail_cc { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_USER 
   global CHECK_MAILX_HOST
   global CHECK_REPORT_EMAIL_CC
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
      if { $config(mailx_host) == "none" } {
         set value "none"
         set only_check 1
      }
   }

   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter e-mail address where the testsuite should cc report mails"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "Set this value to \"none\" if you don't want to cc e-mails from the"
      puts $CHECK_OUTPUT "testsuite."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   # set global values
   set CHECK_REPORT_EMAIL_CC $value

   return $value
}

#****** config/config_enable_error_mails() **************************************
#  NAME
#     config_enable_error_mails() -- error mail setup
#
#  SYNOPSIS
#     config_enable_error_mails { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_enable_error_mails { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_USER 
   global CHECK_MAILX_HOST
   global CHECK_REPORT_EMAIL_TO
   global CHECK_REPORT_EMAIL_CC
   global CHECK_SEND_ERROR_MAILS
   global CHECK_MAX_ERROR_MAILS
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value
   if { $actual_value == "" } {
      set value $default_value
      if { $config(mailx_host) == "none" } {
         set value "none"
         set only_check 1
      }
   }

   if { $only_check == 0 } {
      # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please enter the maximum number of e-mails you want to get from the"
      puts $CHECK_OUTPUT "testsuite or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "Set this value to \"none\" if you don't want to get e-mails from the"
      puts $CHECK_OUTPUT "testsuite."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   if { $value != "none" } {
      if { $CHECK_MAILX_HOST == "none" } {
         puts $CHECK_OUTPUT "mailx host not configured"
         return -1
      }
      set  CHECK_SEND_ERROR_MAILS 1
      set  CHECK_MAX_ERROR_MAILS $value
      if { $only_check == 0 } {
         send_mail $CHECK_REPORT_EMAIL_TO $CHECK_REPORT_EMAIL_CC "Welcome!" "Testsuite mail setup test mail"
         puts $CHECK_OUTPUT "Have you got the e-mail? (y/n) "
         set input [wait_for_enter 1]
         if { $input != "y" }  {
            puts $CHECK_OUTPUT "disabling e-mail ..."
            set CHECK_SEND_ERROR_MAILS 0
            set CHECK_MAX_ERROR_MAILS 0
            set value "none"
         }
      }
   } else {
      set  CHECK_SEND_ERROR_MAILS 0
      set  CHECK_MAX_ERROR_MAILS 0
   }

   return $value
}



#****** config/config_l10n_test_locale() ****************************************
#  NAME
#     config_l10n_test_locale() -- l10n option setup
#
#  SYNOPSIS
#     config_l10n_test_locale { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_l10n_test_locale { only_check name config_array } {
   global CHECK_OUTPUT 
   global CHECK_L10N ts_host_config ts_config
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
#     # do setup  
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please specify the locale for localization (l10n) test."
      puts $CHECK_OUTPUT "Enter \"none\" for no l10n testing."
      puts $CHECK_OUTPUT "Enter \"fr\", \"ja\" or \"zh\" to enable french, japanese or chinese"
      puts $CHECK_OUTPUT "l10n testing or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   }

   set CHECK_L10N 0
   if { ([string compare "none"   $value ] != 0) } {
        
        if { [string compare "fr" $value ] == 0 || 
             [string compare "ja" $value ] == 0 ||
             [string compare "zh" $value ] == 0 } {

           if {!$fast_setup} {
              set was_error 0

              if { [ info exist ts_host_config($ts_config(master_host),${value}_locale)] != 1 } {
                 puts $CHECK_OUTPUT "can't read ts_host_config($ts_config(master_host),${value}_locale)"
                 return -1
              }

              if { $ts_host_config($ts_config(master_host),${value}_locale) == "" } {
                 puts $CHECK_OUTPUT "locale not defined for master host $ts_config(master_host)"
                 incr was_error 1
              }
              foreach host $config(execd_hosts) {
                 if { $ts_host_config($host,${value}_locale) == "" } {
                    puts $CHECK_OUTPUT "locale not defined for execd host $host"
                    incr was_error 1
                 }
              }
              foreach host $ts_config(submit_only_hosts) {
                 if { $ts_host_config($host,${value}_locale) == "" } {
                    puts $CHECK_OUTPUT "locale not defined for submit host $host"
                    incr was_error 1
                 }
              }
              if { $was_error != 0 } {
                 if { $only_check == 0 } {
                     puts $CHECK_OUTPUT "Press enter to edit global host configuration ..."
                     wait_for_enter
                     setup_host_config $config(host_config_file) 1
                 }
                 return -1
              }
           }
           set CHECK_L10N 1
           set mem_value $ts_config(l10n_test_locale)
           set ts_config(l10n_test_locale) $value
           set ts_config(l10n_test_locale) $mem_value

           if {!$fast_setup} {
              set test_result [perform_simple_l10n_test]
              if { $test_result != 0 } {
                 puts $CHECK_OUTPUT "l10n errors" 
                 set CHECK_L10N 0
                 return -1
              }
           }
        } else {
           puts $CHECK_OUTPUT "unexpected locale setting"
           return -1
        }
   }

   return $value
}

#****** config/config_testsuite_gridengine_version() ***************************
#  NAME
#     config_testsuite_gridengine_version() -- version setup
#
#  SYNOPSIS
#     config_testsuite_gridengine_version { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_testsuite_gridengine_version { only_check name config_array } {
   global CHECK_OUTPUT 
   global ts_config fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   if { $actual_value == "" } {
      set value $default_value
   }

   # called from setup
   if { $only_check == 0 } {
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please specify the gridengine version for testsuite"
      puts $CHECK_OUTPUT "Enter \"53\" for SGE(EE) 5.3 systems (e.g. V53_beta2_BRANCH),"
      puts $CHECK_OUTPUT "Enter \"60\" for N1GE 6.0 systems (e.g. V60s2_BRANCH)"
      puts $CHECK_OUTPUT "Enter \"61\" for N1GE 6.1 systems (e.g. V61_BRANCH)"
      puts $CHECK_OUTPUT "Enter \"62\" for N1GE 6.2 systems (e.g. maintrunk)"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   # check parameter
   if {!$fast_setup} {
      if {[string compare $value "53"] != 0 &&
          [string compare $value "60"] != 0 &&
          [string compare $value "61"] != 0 && 
          [string compare $value "62"] != 0} {
         puts $CHECK_OUTPUT "invalid testsuite gridengine version"
         return -1
      }
   }

   return $value
}

#****** config/config_testsuite_spooling_method() ***************************
#  NAME
#     config_testsuite_spooling_method() -- spooling method setup
#
#  SYNOPSIS
#     config_testsuite_spooling_method { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_testsuite_spooling_method { only_check name config_array } {
   global CHECK_OUTPUT CHECK_USER
   global ts_config fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   if { $actual_value == "" } {
      set value $default_value
   }

   # called from setup
   if { $only_check == 0 } {
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please specify the spooling method that will be used"
      puts $CHECK_OUTPUT "in case the binaries were build to support"
      puts $CHECK_OUTPUT "dynamic spooling."
      puts $CHECK_OUTPUT "Can be either \"berkeleydb\" or \"classic\""
      puts $CHECK_OUTPUT ""
      puts $CHECK_OUTPUT "Press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   if {! $fast_setup} {
      # check parameter
      if { [string compare $value "berkeleydb"] != 0 && 
           [string compare $value "classic"] != 0} {
         puts $CHECK_OUTPUT "invalid spooling method $value"
         return -1
      }
   }

   return $value
}

#****** config/config_testsuite_bdb_server() ***************************
#  NAME
#     config_testsuite_bdb_server() -- bdb server setup
#
#  SYNOPSIS
#     config_testsuite_bdb_server { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_testsuite_bdb_server { only_check name config_array } {
   global CHECK_OUTPUT CHECK_USER
   global ts_config ts_host_config
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   if { $actual_value == "" } {
      set value $default_value
   }

   # called from setup
   if { $only_check == 0 } {
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please specify the host of a Berkeley DB RPC server"
      puts $CHECK_OUTPUT ""
      puts $CHECK_OUTPUT "A Berkeley DB RPC server is used, if you want to run"
      puts $CHECK_OUTPUT "the shadowd tests or if you don't want to configure"
      puts $CHECK_OUTPUT "a database directory on a local filesystem"
      puts $CHECK_OUTPUT ""
      puts $CHECK_OUTPUT "Enter \"none\" if you use local spooling"
      puts $CHECK_OUTPUT "or press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
      if {$value != "none"} {
         config_select_host $value config
      }
   }

   # check parameter
   if {!$fast_setup} {
      if {$value != "none"} {
         if {![host_conf_is_supported_host $value]} {
            return -1
         }

         if {[compile_check_compile_hosts $value] != 0} {
            return -1
         }
      }
   }

   return $value
}

#****** config/config_testsuite_bdb_dir() ***************************
#  NAME
#     config_testsuite_bdb_dir() -- bdb database directory setup
#
#  SYNOPSIS
#     config_testsuite_bdb_dir { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_testsuite_bdb_dir { only_check name config_array } {
   global CHECK_OUTPUT 
   global ts_config
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   if { $actual_value == "" } {
      set value $default_value
   }

   # called from setup
   if { $only_check == 0 } {
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please specify the database directory for spooling"
      puts $CHECK_OUTPUT "with the Berkeley DB spooling framework"
      puts $CHECK_OUTPUT ""
      puts $CHECK_OUTPUT "If your testsuite host configuration defines a local"
      puts $CHECK_OUTPUT "spool directory for your master host, specify \"none\""
      puts $CHECK_OUTPUT ""
      puts $CHECK_OUTPUT "If no local spool directory is defined in the host"
      puts $CHECK_OUTPUT "configuration, give the path to a local database"
      puts $CHECK_OUTPUT "directory."
      puts $CHECK_OUTPUT ""
      puts $CHECK_OUTPUT "If you configured a Berkeley DB RPC server, enter"
      puts $CHECK_OUTPUT "the database directory on the RPC server host."
      puts $CHECK_OUTPUT ""
      puts $CHECK_OUTPUT "Press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         if { [string compare "none" $input ] != 0 } {
            # only tail to directory name when != "none"
            set value [tail_directory_name $input]
         } else {
            # we don't have a directory
            set value $input 
         }
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   if {!$fast_setup} {
      if { [string compare "none" $value ] != 0 } {
         if { [tail_directory_name $value] != $value } {
            puts $CHECK_OUTPUT "\nPath \"$value\" is not a valid directory name, try \"[tail_directory_name $value]\""
            return -1
         }
      }
   }
 
   return $value
}

#****** config/config_testsuite_cell() ***************************
#  NAME
#     config_testsuite_cell() -- cell name
#
#  SYNOPSIS
#     config_testsuite_cell { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_testsuite_cell { only_check name config_array } {
   global CHECK_OUTPUT 
   global ts_config
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   if { $actual_value == "" } {
      set value $default_value
   }

   # called from setup
   if { $only_check == 0 } {
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please specify the cell name (SGE_CELL)"
      puts $CHECK_OUTPUT ""
      puts $CHECK_OUTPUT "Press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 

   return $value
}

#****** config/config_testsuite_cluster_name() ***************************
#  NAME
#     config_testsuite_cluster_name() -- cluster name
#
#  SYNOPSIS
#     config_testsuite_cluster_name { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_testsuite_cluster_name { only_check name config_array } {
   global CHECK_OUTPUT 
   global ts_config
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   if { $actual_value == "" } {
      set value $default_value
   }

   # called from setup
   if { $only_check == 0 } {
      puts $CHECK_OUTPUT "" 
      puts $CHECK_OUTPUT "Please specify the cluster name (SGE_CLUSTER_NAME)"
      puts $CHECK_OUTPUT ""
      puts $CHECK_OUTPUT "Press >RETURN< to use the default value."
      puts $CHECK_OUTPUT "(default: $value)"
      puts -nonewline $CHECK_OUTPUT "> "
      set input [ wait_for_enter 1]
      if { [ string length $input] > 0 } {
         set value $input 
      } else {
         puts $CHECK_OUTPUT "using default value"
      }
   } 
   return $value
}

#****** config/config_add_compile_archs() ***************************************
#  NAME
#     config_add_compile_archs() -- forced compilation setup
#
#  SYNOPSIS
#     config_add_compile_archs { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_add_compile_archs { only_check name config_array } {
   global CHECK_OUTPUT 
   global ts_host_config
   global fast_setup

   upvar $config_array config
   set actual_value  $config($name)
   set default_value $config($name,default)
   set description   $config($name,desc)
   set value $actual_value

   if { $actual_value == "" } {
      set value $default_value
   }

   if { $only_check == 0 } {
#      # do setup  
       if { $value == "none" } {
          set value ""
       }
       puts $CHECK_OUTPUT "" 
       set selected $value
       while { 1 } {
          clear_screen
          puts $CHECK_OUTPUT "----------------------------------------------------------"
          puts $CHECK_OUTPUT $description
          puts $CHECK_OUTPUT "----------------------------------------------------------"

          set selected [lsort $selected]
          puts $CHECK_OUTPUT "\nSelected additional compile architectures:"

          puts $CHECK_OUTPUT "----------------------------------------------------------"
          foreach elem $selected { puts $CHECK_OUTPUT $elem }
          puts $CHECK_OUTPUT "----------------------------------------------------------"

          host_config_hostlist_show_compile_hosts ts_host_config arch_array
          puts $CHECK_OUTPUT "\n"
          puts -nonewline $CHECK_OUTPUT "Please enter architecture/number or return to exit: "
         
          set new_arch [wait_for_enter 1]
          if { [ string length $new_arch ] == 0 } {
             break
          }
          if { [string is integer $new_arch] } {
             if { $new_arch >= 1 && $new_arch <= $arch_array(count) } {
                set new_arch $arch_array($new_arch,arch)
             }
          }

          # now we have arch string in new_arch
          set found_arch 0
          foreach host $ts_host_config(hostlist) {
             if {[host_conf_is_compile_host $host]} {
                set compile_arch [host_conf_get_arch $host]
                if { [ string compare $compile_arch $new_arch ] == 0 } {
                   set found_arch 1
                   break
                }
             }
          }
          if { $found_arch == 0 } {
             puts $CHECK_OUTPUT "architecture \"$new_arch\" not found in list"
             wait_for_enter
             continue
          }

          if { [ lsearch -exact $selected $new_arch ] < 0 } {
             append selected " $new_arch"
          } else {
             set index [lsearch $selected $new_arch ]
             set selected [ lreplace $selected $index $index ]
          }
       }
       
       set value [string trim $selected]
       if { $value == "" } {
          set value "none"
       }
   }

   return $value
}

#****** config/config_shadowd_hosts() *********************************************
#  NAME
#     config_shadowd_hosts() -- shadowd daemon host setup
#
#  SYNOPSIS
#     config_shadowd_hosts { only_check name config_array } 
#
#  FUNCTION
#     Testsuite configuration setup - called from verify_config()
#
#  INPUTS
#     only_check   - 0: expect user input
#                    1: just verify user input
#     name         - option name (in ts_config array)
#     config_array - config array name (ts_config)
#
#  SEE ALSO
#     check/setup2()
#     check/verify_config()
#*******************************************************************************
proc config_shadowd_hosts { only_check name config_array } {
   global CHECK_OUTPUT
   global CHECK_CORE_SHADOWD
   global ts_host_config
   global fast_setup

   set CHECK_CORE_SHADOWD ""

   upvar $config_array config
   set value $config($name)
 
   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts $CHECK_OUTPUT "Could not get local host name" 
      return -1
   }

   if {$only_check == 0} {
      # initialize value from defaults, if not yet set
      if {$value == ""} {
         set value $config($name,default)
         if {$value == ""} {
            set value $local_host
         }
      }

      # edit the shadow host list, check_host must be first host
      set value [config_select_host_list config $name $value]
      set value [config_check_host_in_hostlist $value]
   } 

   if {!$fast_setup} {
      if {![config_verify_hostlist $value "shadowd" 1]} {
         return -1
      }
   }

   set CHECK_CORE_SHADOWD $value

   return $value
}


proc config_build_ts_config {} {
   global ts_config
   global CHECK_CURRENT_WORKING_DIR

   # ts_config defaults 
   set ts_pos 1
   set parameter "version"
   set ts_config($parameter)            "1.0"
   set ts_config($parameter,desc)       "Testsuite configuration setup"
   set ts_config($parameter,default)    "1.0"
   set ts_config($parameter,setup_func) ""
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "testsuite_root_dir"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Testsuite's root directory"
   set ts_config($parameter,default)    $CHECK_CURRENT_WORKING_DIR
   set ts_config($parameter,setup_func) "config_testsuite_root_dir"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "checktree_root_dir"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Testsuite's checktree directory"
   set ts_config($parameter,default)    ""   ;# depend on testsuite root dir 
   set ts_config($parameter,setup_func) "config_checktree_root_dir"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "results_dir"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Testsuite's directory to save test results (html/txt files)"
   set ts_config($parameter,default)    ""   ;# depend on testsuite root dir
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "use_ssh"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Using ssh to connect to cluster hosts"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1


   set parameter "source_dir"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Path to Grid Engine source directory"
   set ts_config($parameter,default)    ""   ;# depend on testsuite root dir
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "source_cvs_hostname"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Host used for cvs commands"
   set ts_config($parameter,default)    ""   ;# depend on testsuite root dir
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "source_cvs_release"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Used cvs release tag"
   set ts_config($parameter,default)    ""   ;# depend on testsuite root dir
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "host_config_file"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Testsuite's global cluster host configuration file"
   set ts_config($parameter,default)    $CHECK_CURRENT_WORKING_DIR/testsuite_host.conf
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "user_config_file"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Testsuite's global user configuration file"
   set ts_config($parameter,default)    $CHECK_CURRENT_WORKING_DIR/testsuite_user.conf
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "master_host"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine master host"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "execd_hosts"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine execution daemon hosts"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "submit_only_hosts"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine submit only hosts"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "commd_port"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine COMMD_PORT"
   set ts_config($parameter,default)    "7778"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "product_root"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine directory"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1


   set parameter "product_type"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine product mode"
   set ts_config($parameter,default)    "sgeee"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "product_feature"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine features"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "aimk_compile_options"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Aimk compile options"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "compile"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "dist_install_options"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Distribution install options"
   set ts_config($parameter,default)    "-allall"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "compile"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "qmaster_install_options"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine qmaster install options"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "execd_install_options"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine execd install options"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "package_directory"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Directory with Grid Engine pkgadd or zip file packages"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "compile"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "package_type"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Default package type to test"
   set ts_config($parameter,default)    "tar"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "compile"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "dns_domain"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Local DNS domain name"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "dns_for_install_script"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "DNS domain name used in Grid Engine installation procedure"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "mailx_host"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Name of host used for sending mails (mailx/sendmail must work on this host)"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "report_mail_to"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "E-mail address used for report mails"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "report_mail_cc"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "E-mail address used for cc report mails"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

   set parameter "enable_error_mails"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Max number of e-mails send through one testsuite session"
   set ts_config($parameter,default)    "400"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $ts_pos
   incr ts_pos 1

}

proc config_build_ts_config_1_1 {} {
   global ts_config

   # insert new parameter after product_feature parameter
   set insert_pos $ts_config(product_feature,pos)
   incr insert_pos 1
   
   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   # new parameter l10n_test_locale
   set parameter "l10n_test_locale"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Specify localization environment (LANG)"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos) $insert_pos

   # now we have a configuration version 1.1
   set ts_config(version) "1.1"
}

proc config_build_ts_config_1_2 {} {
   global ts_config

   # insert new parameter after submit_only_hosts parameter
   set insert_pos $ts_config(submit_only_hosts,pos)
   incr insert_pos 1
   
   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   # new parameter add_compile_archs
   set parameter "add_compile_archs"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Forced compilation for architectures"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos) $insert_pos

   # now we have a configuration version 1.2
   set ts_config(version) "1.2"
}

proc config_build_ts_config_1_3 {} {
   global ts_config

   # insert new parameter after version parameter
   set insert_pos $ts_config(version,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   # new parameter gridengine_version
   set parameter "gridengine_version"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Gridengine Version, e.g. 53 for SGE(EE) 5.3, or 60 for N1GE 6.0"
   set ts_config($parameter,default)    "62"
   set ts_config($parameter,setup_func) "config_testsuite_gridengine_version"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.3
   set ts_config(version) "1.3"
}

proc config_build_ts_config_1_4 {} {
   global ts_config

   # insert new parameter after product_feature parameter
   set insert_pos $ts_config(product_feature,pos)
   incr insert_pos 1

   # move positions of following parameters by 2
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 2 ) ]
      }
   }

   # new parameter bdb_server
   set parameter "bdb_server"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Berkeley Database RPC server (none for local spooling)"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_testsuite_bdb_server"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   incr insert_pos 1

   # new parameter bdb_dir
   set parameter "bdb_dir"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Berkeley Database database directory"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_testsuite_bdb_dir"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.4
   set ts_config(version) "1.4"
}

proc config_build_ts_config_1_5 {} {
   global ts_config

   # insert new parameter after product_feature parameter
   set insert_pos $ts_config(product_feature,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   # new parameter spooling method
   set parameter "spooling_method"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Spooling method for dynamic spooling"
   set ts_config($parameter,default)    "berkeleydb"
   set ts_config($parameter,setup_func) "config_testsuite_spooling_method"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.5
   set ts_config(version) "1.5"
}

proc config_build_ts_config_1_6 {} {
   global ts_config

   # insert new parameter after product_feature parameter
   set insert_pos $ts_config(product_feature,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   # new parameter spooling method
   set parameter "cell"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "cell name (SGE_CELL)"
   set ts_config($parameter,default)    "default"
   set ts_config($parameter,setup_func) "config_testsuite_cell"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.6
   set ts_config(version) "1.6"
}
proc config_build_ts_config_1_7 {} {
   global ts_config

   # insert new parameter after commd_port parameter
   set insert_pos $ts_config(commd_port,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   # new parameter reserved port
   set parameter "reserved_port"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Port < 1024 to test root bind() of this port"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_reserved_port"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.7
   set ts_config(version) "1.7"
}
  
proc config_build_ts_config_1_8 {} {
   global ts_config

   # insert new parameter after master_host parameter
   set insert_pos $ts_config(master_host,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   set parameter "shadowd_hosts"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Grid Engine shadow daemon hosts"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "install"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.8
   set ts_config(version) "1.8"
}

proc config_build_ts_config_1_9 {} {
   global ts_config

   # insert new parameter after master_host parameter
   set insert_pos $ts_config(dns_for_install_script,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if { $ts_config($name) >= $insert_pos } {
         set ts_config($name) [ expr ( $ts_config($name) + 1 ) ]
      }
   }

   set parameter "mail_application"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Name of mail application used for sending testsuite mails"
   set ts_config($parameter,default)    "mailx"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.9
   set ts_config(version) "1.9"
}

proc config_build_ts_config_1_91 {} {
   global ts_config

   # insert new parameter after checktree_root_dir
   set insert_pos $ts_config(checktree_root_dir,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if {$ts_config($name) >= $insert_pos} {
         set ts_config($name) [expr $ts_config($name) + 1]
      }
   }

   set parameter "additional_checktree_dirs"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Additional Testsuite's checktree directories"
   set ts_config($parameter,default)    ""   ;# depend on testsuite root dir 
   set ts_config($parameter,setup_func) "config_additional_checktree_dirs"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.91
   set ts_config(version) "1.91"
}

proc config_build_ts_config_1_10 {} {
   global ts_config

   # we renamed the version planned to be 6.5 to 6.1
   if {$ts_config(gridengine_version) == 65} {
      set ts_config(gridengine_version) 62
   }

   # now we have a configuration version 1.10
   set ts_config(version) "1.10"
}

proc config_build_ts_config_1_11 {} {
   global ts_config

   # we add a new parameter: additional_config
   # after additional_checktree_dirs
   set insert_pos $ts_config(additional_checktree_dirs,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if {$ts_config($name) >= $insert_pos} {
         set ts_config($name) [expr $ts_config($name) + 1]
      }
   }

   set parameter "additional_config"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Additional Testsuite Configurations"
   set ts_config($parameter,default)    ""
   set ts_config($parameter,setup_func) "config_additional_config"
   set ts_config($parameter,onchange)   "compile"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.11
   set ts_config(version) "1.11"
}

proc config_build_ts_config_1_12 {} {
   global ts_config

   # we override a the parameter: use_ssh
   set insert_pos $ts_config(use_ssh,pos)

   unset ts_config(use_ssh)
   unset ts_config(use_ssh,desc)
   unset ts_config(use_ssh,default)
   unset ts_config(use_ssh,setup_func)
   unset ts_config(use_ssh,onchange)
   unset ts_config(use_ssh,pos)
   
   set parameter "connection_type"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Starter method for remote connections"
   set ts_config($parameter,default)    "rlogin"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.11
   set ts_config(version) "1.12"
}

proc config_build_ts_config_1_13 {} {
   global ts_config

   
   # we override a the parameter: use_ssh
   set insert_pos $ts_config(commd_port,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if {$ts_config($name) >= $insert_pos} {
         set ts_config($name) [expr $ts_config($name) + 1]
      }
   }

   set parameter "jmx_port"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Port of qmasters jmx mbean server"
   set ts_config($parameter,default)    "0"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.13
   set ts_config(version) "1.13"
}

proc config_build_ts_config_1_14 {} {
   global ts_config

   # we add a new parameter: cluster_name
   # after additional_checktree_dirs
   set insert_pos $ts_config(cell,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if {$ts_config($name) >= $insert_pos} {
         set ts_config($name) [expr $ts_config($name) + 1]
      }
   }

   set parameter "cluster_name"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "cluster name (SGE_CLUSTER_NAME)"
   set ts_config($parameter,default)    "p$ts_config(commd_port)"
   set ts_config($parameter,setup_func) "config_testsuite_cluster_name"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.14
   set ts_config(version) "1.14"
}

proc config_build_ts_config_1_15 {} {
   global ts_config

   # insert new parameter after user_config_file
   set insert_pos $ts_config(user_config_file,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if {$ts_config($name) >= $insert_pos} {
         set ts_config($name) [expr $ts_config($name) + 1]
      }
   }

   set parameter "db_config_file"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "Testsuite's global database configuration file"
   set ts_config($parameter,default)    "none"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   ""
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.15
   set ts_config(version) "1.15"
}

proc config_build_ts_config_1_16 {} {
   global ts_config

   # we add two new parameters: jmx_ssl and jmx_ssl_client
   # after JMX port
   set insert_pos $ts_config(jmx_port,pos)
   incr insert_pos 1

   # move positions of following parameters
   set names [array names ts_config "*,pos"]
   foreach name $names {
      if {$ts_config($name) >= $insert_pos} {
         set ts_config($name) [expr $ts_config($name) + 3]
      }
   }

   set parameter "jmx_ssl"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "JMX SSL server authentication"
   set ts_config($parameter,default)    "false"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   incr insert_pos 1

   set parameter "jmx_ssl_client"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "JMX SSL client authentication"
   set ts_config($parameter,default)    "false"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   incr insert_pos 1

   set parameter "jmx_ssl_keystore_pw"
   set ts_config($parameter)            ""
   set ts_config($parameter,desc)       "JMX SSL keystore pw"
   set ts_config($parameter,default)    "changeit"
   set ts_config($parameter,setup_func) "config_$parameter"
   set ts_config($parameter,onchange)   "stop"
   set ts_config($parameter,pos)        $insert_pos

   # now we have a configuration version 1.16
   set ts_config(version) "1.16"
}

#****** config/config_select_host() ********************************************
#  NAME
#     config_select_host() -- select a host
#
#  SYNOPSIS
#     config_select_host { host config_var } 
#
#  FUNCTION
#     Lets the user select a hostname, e.g. as master host, or as bdb_server
#     host.
#
#     Verifications are done to ensure, that the hostname is valid,
#     configured in the testsuite host configuration, and that
#     a compile host is known for the selected hosts architecture.
#
#  INPUTS
#     host       - the currently selected hostname
#     config_var - configuration array, default ts_host_config
#
#  RESULT
#     The name of the selected host.
#
#  SEE ALSO
#     config/config_select_host_list()
#*******************************************************************************
proc config_select_host {host config_var} {
   global ts_config ts_host_config CHECK_OUTPUT

   upvar $config_var config

   # if host is not yet known, try to add it
   if {![host_conf_is_known_host $host]} {
      puts $CHECK_OUTPUT "Press enter to add host \"$host\" to global host configuration ..."
      wait_for_enter
      set errors 0
      incr errors [host_config_hostlist_add_host ts_host_config  $host]
      incr errors [host_config_hostlist_edit_host ts_host_config $host]
      incr errors [save_host_configuration $config(host_config_file)]
      if {$errors != 0} {
         setup_host_config $config(host_config_file) 1
      }
   }

   if {[compile_check_compile_hosts $host] != 0} {
      puts $CHECK_OUTPUT "Press enter to edit global host configuration ..."
      wait_for_enter
      setup_host_config $config(host_config_file) 1
   }
}

#****** config/config_select_host_list() ***************************************
#  NAME
#     config_select_host_list() -- select hosts from a host list
#
#  SYNOPSIS
#     config_select_host_list { config_var name selected } 
#
#  FUNCTION
#     Allows the user to select a number of hosts from the list of
#     configured and supported hosts.
#
#     Verifications are done to ensure, that the hosts are valid,
#     configured in the testsuite host configuration, and that
#     compile hosts are known for the selected hosts architectures.
#
#  INPUTS
#     config_var - configuration array, default ts_host_config
#     name       - name of the testsuite configuration item, e.g.
#                  "execd_hosts", or "submit_only_hosts"
#     selected   - list of currently selected hosts
#
#  RESULT
#     list of selected hosts
#
#  SEE ALSO
#     config/config_select_host()
#*******************************************************************************
proc config_select_host_list {config_var name selected {help_descr ""} {only_one_host 0} } {
   global ts_config ts_host_config CHECK_OUTPUT

   upvar $config_var config

   set description   $config($name,desc)

   while {1} {
      # output description and host lists
      clear_screen
      puts $CHECK_OUTPUT "----------------------------------------------------------"
      puts $CHECK_OUTPUT $description
      if { $help_descr != "" } {
         puts $CHECK_OUTPUT "----------------------------------------------------------"
         foreach elem $help_descr { puts $CHECK_OUTPUT $elem }
      }
      puts $CHECK_OUTPUT "----------------------------------------------------------"
        
      set selected [lsort $selected]
      puts $CHECK_OUTPUT "\nSelected hosts:"
      puts $CHECK_OUTPUT "----------------------------------------------------------"
      foreach elem $selected { puts $CHECK_OUTPUT $elem }
      puts $CHECK_OUTPUT "----------------------------------------------------------"
      set hostlist [host_config_hostlist_show_hosts ts_host_config]
      puts $CHECK_OUTPUT "\n"
      puts $CHECK_OUTPUT "Please enter"
      puts $CHECK_OUTPUT "  - \"all\" to select all hosts in list,"
      puts $CHECK_OUTPUT "  - \"none\" to remove all hosts from list,"
      puts $CHECK_OUTPUT "  - return to exit, or"
      puts -nonewline $CHECK_OUTPUT "  - a hostname / host number: "
     
      # wait for user input
      set host [wait_for_enter 1]

      # user pressed return for exit
      if {[string length $host] == 0} {
         if { $only_one_host != 0 } {
            if {[llength $selected] > 1 } {
               puts $CHECK_OUTPUT "only one host allowed, please select only one host!"
               wait_for_enter
               continue
            } 
            if {[llength $selected] < 1 } {
               puts $CHECK_OUTPUT "please select a host!"
               wait_for_enter
               continue
            } 
         }
         break
      }

      # user entered "all"
      if {[string compare $host "all"] == 0} {
         set selected $hostlist
         continue
      }

      # user entered "none"
      if {[string compare $host "none"] == 0} {
         set selected ""
         continue
      }

      # user entered a host number
      if {[string is integer $host]} {
         if {$host < 1 || $host > [llength $hostlist]} {
            puts $CHECK_OUTPUT "invalid host number or host name"
            wait_for_enter
            continue
         }
         incr host -1
         set host [lindex $hostlist $host]
      }

      # unknown or unsupported host
      if {![host_conf_is_supported_host $host]} {
         # If the host is in selected host, but no longer in host config,
         # or not supported in the configured Grid Engine version, delete it.
         set selected_idx [lsearch -exact $selected $host]
         if {$selected_idx >= 0} {
            set selected [lreplace $selected $selected_idx $selected_idx]
            continue
         } else {
            wait_for_enter
            continue
         }
      }

      # host is ok: add or remove
      if {[lsearch -exact $selected $host] < 0} {
          lappend selected $host
      } else {
         set index [lsearch $selected $host]
         set selected [lreplace $selected $index $index]
      }
   }

   # make sure we have compile hosts for all selected hosts
   if {[compile_check_compile_hosts $selected] != 0} {
      puts $CHECK_OUTPUT "Press enter to edit global host configuration ..."
      wait_for_enter
      setup_host_config $config(host_config_file) 1
   }

   if { $only_one_host != 0 } {
      if { [llength $selected] > 1} {
         add_proc_error "config_select_host_list" -1 "please select only one host"
         return ""
      }
   }

   return $selected
}

#****** config/config_check_host_in_hostlist() *********************************
#  NAME
#     config_check_host_in_hostlist() -- ensure [gethostname] is first in list
#
#  SYNOPSIS
#     config_check_host_in_hostlist { hostlist } 
#
#  FUNCTION
#     The function ensures, that [gethostname] is the first host in a given
#     host list.
#
#  INPUTS
#     hostlist - host list to verify
#
#  RESULT
#     a new host list, with [gethostname] as first element
#*******************************************************************************
proc config_check_host_in_hostlist {hostlist} {

   # make sure, [gethostname] is the first host in list
   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts $CHECK_OUTPUT "Could not get local host name" 
      return -1
   }
   set index [lsearch $hostlist $local_host]
   if {$index >= 0} {
      set hostlist [lreplace $hostlist $index $index]
   }
   set hostlist [linsert $hostlist 0 $local_host]

   return $hostlist
}

#****** config/config_verify_hostlist() ****************************************
#  NAME
#     config_verify_hostlist() -- verify a list of hosts
#
#  SYNOPSIS
#     config_verify_hostlist { hostlist name {check_host_first 0} } 
#
#  FUNCTION
#     Verifies correctness of a list of host names:
#     - the hosts must be configured in the testsuite host configuration
#     - compile hosts must be known for all the hosts architectures
#     - if requested (argument check_host_first), [gethostname] has to be the
#       first host in the given host list
#     
#  INPUTS
#     hostlist             - the list to verify
#     name                 - name of the testsuite configuration item, e.g.
#                            "execd_hosts", or "submit_only_hosts"
#     {check_host_first 0} - has [gethostname] to be the first list element?
#
#  RESULT
#     0: host list is invalid, reasons will be output to $CHECK_OUTPUT
#     1: host list is OK
#
#  SEE ALSO
#     config/config_check_host_in_hostlist()
#     config_host/host_conf_is_supported_host()
#     compile/compile_check_compile_hosts()
#*******************************************************************************
proc config_verify_hostlist {hostlist name {check_host_first 0}} {
   global ts_config CHECK_OUTPUT

   set local_host [gethostname]
   if {$local_host == "unknown"} {
      puts $CHECK_OUTPUT "Could not get local host name" 
      return 0
   }

   if {$check_host_first} {
      # [gethostname] must be first host
      if {[lindex $hostlist 0] != $local_host} {
         puts $CHECK_OUTPUT "First $name host must be local host"
         return 0
      }
   }

   foreach host $hostlist {
      # Verify that all hosts are configured in host config and
      # supported with the configured Grid Engine version.
      if {![host_conf_is_supported_host $host]} {
         return 0
      }
   }

   if {[compile_check_compile_hosts $hostlist] != 0} {
      return 0
   }

   return 1
}




# MAIN
global actual_ts_config_version      ;# actual config version number
set actual_ts_config_version "1.16"

# first source of config.tcl: create ts_config
if {![info exists ts_config]} {
   config_build_ts_config
   config_build_ts_config_1_1
   config_build_ts_config_1_2
   config_build_ts_config_1_3
   config_build_ts_config_1_4
   config_build_ts_config_1_5
   config_build_ts_config_1_6
   config_build_ts_config_1_7
   config_build_ts_config_1_8
   config_build_ts_config_1_9
   config_build_ts_config_1_91
   config_build_ts_config_1_10
   config_build_ts_config_1_11
   config_build_ts_config_1_12
   config_build_ts_config_1_13
   config_build_ts_config_1_14
   config_build_ts_config_1_15
   config_build_ts_config_1_16
}

