package ;

import sys.FileSystem;
import hx.files.Dir;
import haxe.io.Path;
import Database.MapEntry;
import sys.io.Process;

using StringTools;

class Launcher {

    public static var currentProcess:Process;

    public static function launch(mapData:MapEntry, ?startmap:String, ?quakeExePath:String) {
        try {
            if ( quakeExePath == null) {
                quakeExePath = UserState.instance.currentData.quakeExePath;
            }
            if ( startmap == null ) {
                if ( mapData.techinfo != null && mapData.techinfo.startmap != null && mapData.techinfo.startmap.length > 0 ) {
                    startmap = mapData.techinfo.startmap[0];
                } else {
                    // get a list of all BSPs in /maps/ and select a startmap
                    var mapNames = getMapListFromDisk(mapData);
                    if ( mapNames != null) {
                        if ( mapNames.contains("start") ) {
                            startmap = "start";
                        } else {
                            mapNames.sort( sortAlphabetically );
                            startmap = mapNames[0];
                        }
                    }
                }
            }
            var quakeFolderPath = Path.addTrailingSlash( Path.directory( quakeExePath ) );

            var args = new Array<String>(); 
            
            // get command line arguments from database, but strip any "-game" commands out
            if (mapData.techinfo != null && mapData.techinfo.commandline != null && mapData.techinfo.commandline.contains("-game")) {
                args.push( stripGameCommandFromArguments(mapData.techinfo.commandline) );
            }

            args.push("-basedir " + quakeFolderPath); // but older Quake engines don't support this?
            args.push("-game " + Downloader.getModInstallFolderName(mapData) );
            
            if ( startmap != null) {
                args.push("+map " + startmap);
            }

            Notify.instance.addNotify( mapData.id, "LAUNCHING: " + quakeExePath + " " + args.join(" "));
            currentProcess = new Process(quakeExePath + " " + args.join(" "));
        } catch (e) {
            Notify.instance.addNotify( mapData.id, "ERROR, can't launch " + mapData.id + "... " + e.message);
            throw e;
        }
    }

    public static function openInExplorer(filepath:String) {
        Sys.command("start " + filepath);
    }

    static function getMapListFromDisk(mapData:MapEntry) {
        if ( Downloader.isModInstalled(mapData.id) == false) {
            trace("error: can't get map list if the mod isn't installed yet!");
            return null;
        }

        var mapsFolderPath = Path.addTrailingSlash( Downloader.getModInstallFolder(mapData) ) + Path.addTrailingSlash("maps");
        if ( FileSystem.exists(mapsFolderPath) ) {
            var dir = Dir.of(mapsFolderPath);
            var mapFiles = dir.findFiles("*.bsp").map( file -> file.path.filenameStem );
            return mapFiles;
        } else {
            return null;
        }
    }

    static inline function sortAlphabetically(a:String, b:String):Int {
        a = a.toUpperCase();
        b = b.toUpperCase();
      
        if (a < b) {
          return -1;
        }
        else if (a > b) {
          return 1;
        } else {
          return 0;
        }
    }

    static inline function stripGameCommandFromArguments(cmdLine:String) {
        var cmdLineClean = cmdLine.trim();
        while ( cmdLineClean.contains("  ") ) { // take no chances with extra whitespace
            cmdLineClean = cmdLineClean.replace("  ", " ");
        }
        var cmdLineParts = cmdLineClean.split(" ");
        for ( i in 0...cmdLineParts.length) {
            if (cmdLineParts[i].contains("-game") && cmdLineParts.length > i+1 && cmdLineParts[i+1].trim().length > 0) {
                // lol Haxe arrays don't have removeAt() so let's just blank out these array entries
                cmdLineParts[i+1] = "";
                cmdLineParts[i] = "";
                break;
            }
        }
        cmdLineClean = cmdLineParts.join(" ");
        while ( cmdLineClean.contains("  ") ) { // take no chances with extra whitespace
            cmdLineClean = cmdLineClean.replace("  ", " ");
        }
        return cmdLineClean;
    }
}