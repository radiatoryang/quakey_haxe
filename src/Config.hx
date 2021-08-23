package ;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.Process;

using StringTools;

class Config {

    public static function findQuakeFolders() {
        var quakePaths = new Array<String>();

        // registry key and common path lookups from https://github.com/neogeographica/quakestarter/blob/main/quakestarter_scripts/_install_quakefiles.cmd
        regQuery(quakePaths, "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Steam App 2310", "InstallLocation" );
        regQuery(quakePaths, "HKCU\\SOFTWARE\\Valve\\Steam", "SteamPath", "steamapps\\common\\Quake" );
        regQuery(quakePaths, "HKLM\\SOFTWARE\\WOW6432Node\\GOG.com\\Games\\1435828198", "PATH" );
        regQuery(quakePaths, "HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\1435828198_is1", "InstallLocation" );
        regQuery(quakePaths, "HKLM\\SOFTWARE\\WOW6432Node\\Bethesda Softworks\\Bethesda.net", "installLocation", "games\\Quake");
        quakePaths = quakePaths.concat( getCommonPaths() );

        // trace( "Quake search paths:\n" + quakePaths.join("\n") );

        // search all the paths we've accumulated
        for( path in quakePaths ) {
            if ( FileSystem.exists(path) ) {
                if ( (FileSystem.exists(path + "/id1/pak0.pak") || FileSystem.exists(path + "/Id1/pak0.pak")) 
                  && (FileSystem.exists(path + "/id1/pak1.pak") || FileSystem.exists(path + "/Id1/pak1.pak")) 
                ) {
                    trace("found pak0.pak and pak1.pak files!");

                }
            }
        }
    }
    
	static function regQuery(pathArray:Array<String>, regDir:String, key:String, ?suffix:String) {
		// var command = 'reg query $query /v $key';
		var p = new Process('reg', ['query', regDir, '/v', key]);
		if (p.exitCode() != 0) {
			var error = p.stderr.readAll().toString();
			p.close();
            if ( !error.contains("unable to find") ) {
			    throw 'Cannot query reg.exe for PATH:\n$error';
            }
            return;
		}

		/**
		 * Sample response:
		 *
		 *	HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment
		 *	    path    REG_EXPAND_SZ    %SystemRoot%\system32;%SystemRoot%;%SystemRoo<...>
		 */
		var response = p.stdout.readAll().toString().split("    ");
        var path = response[response.length-1].replace("\r", "").replace("\n", "");
		p.close();
        trace('regQuery($regDir, $key) = $path');
		pathArray.push( Path.normalize( Path.addTrailingSlash( path ) + (suffix != null ? suffix : "") ) );
	}

    static function getCommonPaths() {
        var paths = new Array<String>();
        var driveLetters = ["C:\\", "D:\\"]; // TODO: actually fetch the drive letters
        var pathSuffixes = ["Quake", "Steam\\steamapps\\common\\Quake", "GOG Games\\Quake", "GOG Galaxy\\Games\\Quake", "Bethesda.net Launcher\\games\\Quake"];
        for( drive in driveLetters) {
            for( pathSuffix in pathSuffixes ) {
                paths.push(drive + "Program Files (x86)\\" + pathSuffix);
                paths.push(drive + "Program Files\\" + pathSuffix);
                paths.push(drive + "Games\\" + pathSuffix);
                paths.push(drive + pathSuffix);
            }
        }
        return paths;
    }

    // // from https://www.reddit.com/r/haxe/comments/nzc56u/how_do_you_get_the_users_pc_name/
    // static function getUsername() {
    //     var envs = Sys.environment();
    //     if (envs.exists("USERNAME")) { // WINDOWS
    //         return envs["USERNAME"];
    //     }
    //     if (envs.exists("USER")) { // MACOS / LINUX
    //         return envs["USER"];
    //     }    
    //     return null;
    // }
}

typedef ConfigData = {
    var quakePathsFound:Array<String>;
    var pak0path:String;
    var pak1path:String;
}