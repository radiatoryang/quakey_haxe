package ;

import haxe.ui.events.UIEvent;
import haxe.ui.util.Color;
import h3d.impl.VarBinding;
import haxe.ui.events.MouseEvent;
import hxd.File;
import haxe.ui.containers.VBox;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.Process;

using StringTools;

@:build(haxe.ui.ComponentBuilder.build("assets/config-menu.xml"))
class Config extends VBox {

    /** MUST be lowercase!!! **/
    static var quakeEnginePrefixes = ["quake", "vkquake", "glquake", "glqwcl", "qwcl", "winquake", "mark_v", "fte", "glpro", "dx8pro", "joequake", "darkplaces", "fitzquake", "qbism"];

    static var quakePathsFound:Array<String>;
    static var quakeEnginesFound:Array<String>;
    static var quakePak0sFound:Array<String>;
    static var quakePak1sFound:Array<String>;

    var currentConfig:ConfigData;
    var configs:Array<ConfigData> = new Array<ConfigData>();

    public function new() {
        super();
        scanForQuakeFiles();
        refreshValidate(null);
    }

    @:bind( buttonAutoConfig, MouseEvent.CLICK )
    function addAutoConfig(e:MouseEvent) {
		makeNewConfig();        
        currentConfig.name = "Auto Config";
        currentConfig.quakeEnginePath = Main.PROGRAM_DIR + Main.ENGINE_QUAKESPASM_PATH;
        currentConfig.modFolderPath = Path.addTrailingSlash(Main.BASE_DIR + Main.INSTALL_PATH);
        if (quakePak0sFound != null && quakePak0sFound.length > 0)
            currentConfig.pak0path = quakePak0sFound[0];
        if (quakePak1sFound != null && quakePak1sFound.length > 0)
            currentConfig.pak1path = quakePak1sFound[0];

        refreshConfigList();
        // TODO: config dropdown select last
    }

    function makeNewConfig() {
        currentConfig = { name: "New Config", quakeEnginePath: "", modFolderPath: "", pak0path: "", pak1path: "" };
        configs.push(currentConfig);
    }

    function refreshConfigList() {
        configDropdown.dataSource.clear();
        for( config in configs ) {
            configDropdown.dataSource.add( { text: config.name });
        }
    }

    @:bind( configDropdown, UIEvent.CHANGE )
    function onConfigDropdown(e) {
        var index = configDropdown.selectedIndex;
        if ( index >= 0) {
            loadConfig( configs[index] );
        }
    }

    @:bind( buttonNewConfig, MouseEvent.CLICK )
    function addNewConfig(e:MouseEvent) {
		makeNewConfig();
        loadConfig(currentConfig);
    }

    function loadConfig(cfg:ConfigData) {
        if ( cfg == null) return;

        fieldEngine.text = cfg.quakeEnginePath;
        fieldMods.text = cfg.modFolderPath;
        fieldPak0.text = cfg.pak0path;
        fieldPak1.text = cfg.pak1path;
        refreshValidate(null);
    }

    function saveConfig(cfg:ConfigData) {
        if ( cfg == null) return;

        cfg.quakeEnginePath = fieldEngine.text;
        cfg.modFolderPath = fieldMods.text;
        cfg.pak0path = fieldPak0.text;
        cfg.pak1path = fieldPak1.text;
    }

    @:bind( fieldEngine, UIEvent.PROPERTY_CHANGE )
    @:bind( fieldMods, UIEvent.PROPERTY_CHANGE )
    @:bind( fieldPak0, UIEvent.PROPERTY_CHANGE )
    @:bind( fieldPak1, UIEvent.PROPERTY_CHANGE )
    function refreshValidate(e) {
        // needs an active config selected

        // now validate actual config settings
        var validConfig = true;

        if ( fieldEngine.text != null && fieldEngine.text.toLowerCase().endsWith(".exe") && FileSystem.exists(fieldEngine.text) ) {
            fieldEngine.borderColor = "black";
        } else {
            fieldEngine.borderColor = "red";
            validConfig = false;
        }

        if ( fieldMods.text != null && FileSystem.exists(fieldMods.text) && FileSystem.isDirectory(fieldMods.text) ) {
            fieldMods.borderColor = "black";
        } else {
            fieldMods.borderColor = "red";
            validConfig = false;
        }

        if ( fieldPak0.text != null && fieldPak0.text.toLowerCase().endsWith(".pak") && FileSystem.exists(fieldPak0.text) ) {
            fieldPak0.borderColor = "black";
        } else {
            fieldPak0.borderColor = "red";
            validConfig = false;
        }

        if ( fieldPak1.text != null && fieldPak1.text.toLowerCase().endsWith(".pak") && FileSystem.exists(fieldPak1.text) ) {
            fieldPak1.borderColor = "black";
        } else {
            fieldPak1.borderColor = "red";
            validConfig = false;
        }

        // TODO: if paks aren't in the mod folder, then ask to copy them over

        buttonConfigFinish.hidden = !(currentConfig != null && validConfig);
    }

    @:bind( buttonEngineBrowse, MouseEvent.CLICK )
    function browseEngine(e:MouseEvent) {
		File.browse( 
            function(path) {
                if ( path != null && FileSystem.exists(path.fileName) )
                    fieldEngine.text = path.fileName;
            }, {
                title: "Select a Quake Engine...", 
                fileTypes: [{name: "Quake engine (.exe)", extensions: ["exe"]}], 
                defaultPath: fieldEngine.text
            }
        );
    }

    @:bind( buttonModsBrowse, MouseEvent.CLICK )
    function browseModFolder(e:MouseEvent) {
        File.browse( 
            function(path) {
                if ( path != null && FileSystem.exists(path.fileName) )
                    fieldMods.text = Path.directory(path.fileName);
            }, {
                title: "Select any file in your desired mod folder...", 
                fileTypes: [{name: "Any file", extensions: ["*"]}], 
                defaultPath: fieldMods.text
            }
        );
    }

    @:bind( buttonPak0Browse, MouseEvent.CLICK )
    function browsePak0(e:MouseEvent) {
        File.browse( 
            function(path) {
                if ( path != null && FileSystem.exists(path.fileName) )
                    fieldPak0.text = path.fileName;
            }, {
                title: "Select a pak0.pak (probably found in /Quake/id1/)", 
                fileTypes: [{name: "pak0.pak", extensions: ["pak"]}], 
                defaultPath: fieldPak0.text
            }
        );
    }

    @:bind( buttonPak1Browse, MouseEvent.CLICK )
    function browsePak1(e:MouseEvent) {
        File.browse( 
            function(path) {
                if ( path != null && FileSystem.exists(path.fileName) )
                    fieldPak1.text = path.fileName;
            }, {
                title: "Select a pak1.pak (probably found in /Quake/id1/)", 
                fileTypes: [{name: "pak1.pak", extensions: ["pak"]}], 
                defaultPath: fieldPak1.text
            }
        );
    }


    public static function scanForQuakeFiles() {
        trace("beginning Quake scan...");
        var possibleQuakePaths = new Array<String>();
        quakePathsFound = new Array<String>();
        quakePathsFound.push( Path.addTrailingSlash(Main.BASE_DIR + Main.INSTALL_PATH) );
        quakeEnginesFound = new Array<String>();
        quakeEnginesFound.push( Main.PROGRAM_DIR + Main.ENGINE_QUAKESPASM_PATH );
        quakePak0sFound = new Array<String>();
        quakePak1sFound = new Array<String>();

        // registry key and common path lookups from https://github.com/neogeographica/quakestarter/blob/main/quakestarter_scripts/_install_quakefiles.cmd
        regQuery(possibleQuakePaths, "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Steam App 2310", "InstallLocation" );
        regQuery(possibleQuakePaths, "HKCU\\SOFTWARE\\Valve\\Steam", "SteamPath", "steamapps\\common\\Quake\\" );
        regQuery(possibleQuakePaths, "HKLM\\SOFTWARE\\WOW6432Node\\GOG.com\\Games\\1435828198", "PATH" );
        regQuery(possibleQuakePaths, "HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\1435828198_is1", "InstallLocation" );
        regQuery(possibleQuakePaths, "HKLM\\SOFTWARE\\WOW6432Node\\Bethesda Softworks\\Bethesda.net", "installLocation", "games\\Quake\\");
        var lotsMorePaths = getCommonPaths();
        for(anotherPath in lotsMorePaths) {
            if ( !possibleQuakePaths.contains(anotherPath) ) {
                possibleQuakePaths.push(anotherPath);
            }
        }

        // trace( "Quake search paths:\n" + quakePaths.join("\n") );

        // search all the paths we've accumulated
        for( path in possibleQuakePaths ) {
            if ( FileSystem.exists(path) ) {
                var possiblePakLocations = ["/id1/pak0.pak", "/id1/pak1.pak" ];
                var foundAPakHere = false;
                for( pakPath in possiblePakLocations) {
                    if (FileSystem.exists(path + pakPath) ) {
                        foundAPakHere = true;
                        if ( pakPath.contains("pak0") ) {
                            quakePak0sFound.push( Path.normalize(path + pakPath) );
                        } else {
                            quakePak1sFound.push( Path.normalize(path + pakPath) );
                        }
                        trace("found " + Path.normalize(path + pakPath) );
                    }
                }
                if ( foundAPakHere ) {
                    quakePathsFound.push( path );
                    trace("found Quake path " + path);
                    var listOfExes = FileSystem.readDirectory(path).filter( filepath -> filepath.toLowerCase().endsWith(".exe"));
                    for(exeName in listOfExes) {
                        for( enginePrefix in quakeEnginePrefixes ) {
                            if ( exeName.startsWith(enginePrefix) ) {
                                quakeEnginesFound.push( Path.normalize( Path.addTrailingSlash(path) + exeName) );
                                trace("found Quake engine " + exeName);
                                break;
                            }
                        }
                    }
                } // end "found a pak here"

            } // end "quake path exists"
        } // end "possible quake paths"
        trace("Quake scan finished!");
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
        var path = response[response.length-1].replace("\r", "").replace("\n", "").trim();
        path = cleanPath( Path.addTrailingSlash( path ) + (suffix != null ? suffix : "") );
		p.close();
        trace('regQuery($regDir, $key) = $path');
        if ( !pathArray.contains(path) )
		    pathArray.push(path);
	}

    static inline function cleanPath(path:String) {
        return Path.addTrailingSlash( Path.normalize( path ) ).toLowerCase();
    }

    static function getCommonPaths() {
        var paths = new Array<String>();
        var driveLetters = ["C:\\", "D:\\"]; // TODO: actually fetch the drive letters
        var pathSuffixes = ["Quake", "Steam\\steamapps\\common\\Quake", "GOG Games\\Quake", "GOG Galaxy\\Games\\Quake", "Bethesda.net Launcher\\games\\Quake"];
        for( drive in driveLetters) {
            for( pathSuffix in pathSuffixes ) {
                paths.push( cleanPath( drive + "Program Files (x86)\\" + pathSuffix) );
                paths.push( cleanPath( drive + "Program Files\\" + pathSuffix) );
                paths.push( cleanPath( drive + "Games\\" + pathSuffix) );
                paths.push( cleanPath( drive + pathSuffix) );
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

typedef ConfigJSON = {
    var configs: Array<String>;
}

typedef ConfigData = {
    var name:String;
    var quakeEnginePath:String;
    var modFolderPath:String;
    var pak0path:String;
    var pak1path:String;
}