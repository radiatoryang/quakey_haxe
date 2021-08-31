package ;

import sys.io.File;
import hxd.System;
import sys.FileSystem;
import hx.files.Dir;
import haxe.io.Path;
import Database.MapEntry;
import sys.io.Process;

using StringTools;

class Launcher {

    public static var currentProcess:Process;

    public static function launch(?mapData:MapEntry, ?startmap:String, ?baseDir:String, ?quakeExePath:String, suppressNotify:Bool=false) {
        try {
            if ( quakeExePath == null) {
                quakeExePath = Config.instance.lastGoodConfig.quakeEnginePath;
            }
            if ( startmap == null && mapData != null ) {
                if ( mapData.techinfo != null && mapData.techinfo.startmap != null && mapData.techinfo.startmap.length > 0 ) {
                    startmap = mapData.techinfo.startmap[0];
                } else {
                    // get a list of all BSPs in /maps/ and select a startmap
                    var mapNames = Downloader.getMapListFromDisk(mapData);
                    if ( mapNames != null) {
                        // look for a map named start
                        if ( mapNames.contains("start") ) {
                            startmap = "start";
                        }

                        // look for anything with a "start" inside
                        if ( startmap == null) {
                            for( mapName in mapNames) {
                                if ( mapName.toLowerCase().contains("start") ) {
                                    startmap = mapName;
                                    break;
                                }
                            }
                        }

                        // still didn't find one? then just choose the alphabetical one
                        if ( startmap == null) { 
                            mapNames.sort( Search.sortAlphabetically );
                            startmap = mapNames[0];
                        }
                    }
                }
            }

            // TODO: code custom stuff for Quake rerelease?

            var quakeFolderPath = Path.addTrailingSlash( Path.directory( quakeExePath ) );
            if ( baseDir == null ) {
                if (Config.instance.lastGoodConfig != null) {
                    baseDir = Config.instance.lastGoodConfig.modFolderPath;
                } else {
                    baseDir = quakeFolderPath;
                }
            }

            var args = new Array<String>(); 
            
            // get command line arguments from database, but strip any "-game" commands out
            if (mapData != null && mapData.techinfo != null && mapData.techinfo.commandline != null && mapData.techinfo.commandline.contains("-game")) {
                args.push( stripGameCommandFromArguments(mapData.techinfo.commandline) );
            }

            var isQuakeEX = Config.isQuakeEX(quakeExePath);
            var appidPath = Path.addTrailingSlash(quakeFolderPath) + "steam_appid.txt";
            if ( !isQuakeEX ) {
                args.push('-basedir "' + baseDir + '"'); 
            } else {
                if ( quakeExePath.toLowerCase().contains("steam") && !FileSystem.exists(appidPath) ) { // you need a steam_appid.txt next to KexQuake or else you can't launch it from outside of Steam
                    File.saveContent( appidPath, "2310" );
                }
                // args.push('+kf_basepath "' + baseDir + '"');
                args.push('+g_showintromovie 0');
            }

            if (mapData != null) {
                if ( !isQuakeEX ) 
                    args.push( "-game " + Downloader.getModInstallFolderName(mapData) );
                else
                    args.push( "+game " + Downloader.getModInstallFolderName(mapData) );
            }
            
            if ( startmap != null) {
                args.push("+map " + startmap);
            }

            if ( !suppressNotify) {
                Overlay.notify( mapData.id, "LAUNCHING: " + quakeExePath + " " + args.join(" "));
            } else {
                trace("LAUNCHING: " + quakeExePath + " " + args.join(" "));
            }

            // use Steam protocol fallback... which doesn't quite work lol
            if ( isQuakeEX && quakeExePath.toLowerCase().contains("steam") && !FileSystem.exists(appidPath) ) {
                for (i in 0...args.length) {
                    args[i] = args[i].replace("/", "\\");
                }
                var url = "steam://run/2310//" + args.join(" ") + "/";
                trace(url);
                System.openURL(url); 
            } else {
                Sys.setCwd(quakeFolderPath);
                currentProcess = new Process('"' + quakeExePath + '" ' + args.join(" "));
                // if ( currentProcess != null ) {
                //     trace(currentProcess.exitCode(false));
                //     trace( currentProcess.stdout.readAll().toString() );
                //     trace( currentProcess.stderr.readAll().toString() );
                // }
            }
        } catch (e) {
            if ( !suppressNotify && mapData != null) {
                Overlay.notify( mapData.id, "ERROR, can't launch " + mapData.id + "... " + e.message);
            } else {
                trace("ERROR, can't launch " + quakeExePath + "because: " + e.message);
            }
            // throw e;
            return false;
        }
        return true;
    }

    public static function openInExplorer(filepath:String) {
        Sys.command('start "" "' + filepath + '"');
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