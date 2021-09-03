package ;

import haxe.Json;
import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.components.TextField;
import haxe.ui.components.DropDown;
import haxe.ui.containers.menus.MenuItem;
import haxe.ui.events.ItemEvent;
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
    public static var instance:Config;
    static inline var CONFIG_FILENAME = "config.json";

    /** MUST be lowercase!!! **/
    static var quakeEnginePrefixes = ["quake", "vkquake", "glquake", "glqwcl", "qwcl", "winquake", "mark_v", "fte", "glpro", "dx8pro", "joequake", "darkplaces", "fitzquake", "qbism"];
    static var quakePathsFound:Array<String>;
    static var quakeEnginesFound:Array<String>;
    static var quakePak0sFound:Array<String>;
    static var quakePak1sFound:Array<String>;

    var currentData:ConfigJSON;
    public var lastGoodConfig(default, null):ConfigData;
    var currentConfig:ConfigData;
    var configs(get, set):Array<ConfigData>;
    function get_configs() {
        return currentData.configs;
    }
    function set_configs(value) {
        currentData.configs = value;
        return currentData.configs;
    }

    public static function init() {
        instance = new Config();
        return instance;
    }

    private function new() {
        super();
        loadFromFileIfExists();
    }

    override function show() {
        super.show();
        loadFromFileIfExists();
        buttonAutoConfig.hide();
        Main.moveToFrontButBeneathNotifications(this);
        refreshValidate(null);
    }

    inline function generateSelect(dropdown:DropDown, options:Array<String>, placeholderText:String) {
        if ( options != null && options.length > 0 ) {
            dropdown.show();
            dropdown.dataSource.clear();
            for( option in options ) {
                dropdown.dataSource.add( {text: option});
            }
            dropdown.text = ""; //placeholderText + " (" +options.length + ")";
            // dropdown.tooltip = placeholderText + " that Quakey found when it searched";
        } else {
            dropdown.hide();
        }
    }

    @:bind( buttonAutoConfig, MouseEvent.CLICK )
    function addAutoConfig(e:MouseEvent) {
		makeNewConfig();
        currentConfig.name = "Auto Config";
        if (quakeEnginesFound != null && quakeEnginesFound.length > 0)
            currentConfig.quakeEnginePath = quakeEnginesFound[0];
        currentConfig.modFolderPath = Path.addTrailingSlash(Main.BASE_DIR + Main.INSTALL_PATH);
        if (quakePak0sFound != null && quakePak0sFound.length > 0)
            currentConfig.pak0path = quakePak0sFound[0];
        if (quakePak1sFound != null && quakePak1sFound.length > 0)
            currentConfig.pak1path = quakePak1sFound[0];

        loadConfig(currentConfig);
        refreshConfigList();
        configDropdown.selectedIndex = configDropdown.dataSource.size-1;
    }

    function makeNewConfig() {
        currentConfig = { name: "New Config", quakeEnginePath: "", modFolderPath: "", pak0path: "", pak1path: "" };
        configs.push(currentConfig);

        loadConfig(currentConfig);
        refreshConfigList();
        configDropdown.selectedIndex = configDropdown.dataSource.size-1;
    }

    function refreshConfigList() {
        configDropdown.dataSource.clear();
        for( config in configs ) {
            configDropdown.dataSource.add( { text: config.name });
        }
    }

    @:bind( menuEngineSelect, UIEvent.CHANGE )
    @:bind( menuModsSelect, UIEvent.CHANGE )
    @:bind( menuPak0Select, UIEvent.CHANGE )
    @:bind( menuPak1Select, UIEvent.CHANGE )
    function onSelectPathDropdown(e:UIEvent) {
        var dropdown = cast(e.target, DropDown);
        var textField = dropdown.findComponent(null, TextField);
        textField.text = dropdown.text;
        dropdown.text = "";
    }

    @:bind( buttonDeleteConfig, MouseEvent.CLICK)
    function deleteConfig(e) {
        if ( configs != null && configs.length > 0) {
            configs.remove( configs[configDropdown.selectedIndex] );
            configDropdown.dataSource.removeAt( configDropdown.selectedIndex );
            if ( configs.length == 0) {
                configDropdown.selectedIndex = -1;
                configDropdown.text = "(no configs found)";
                loadConfig(null);
            } else {
                configDropdown.selectedIndex = Math.round(Math.min(configDropdown.selectedIndex, configs.length-1));
                loadConfig(configs[configDropdown.selectedIndex]);
                configDropdown.text = currentConfig.name;
            }
        }
    }

    @:bind( buttonRenameConfig, MouseEvent.CLICK)
    function renameConfig(e) {
        var renameDialog = new TextDialog();
        renameDialog.title = "Rename Config";
        renameDialog.defaultValue = "My Config";
        renameDialog.onDialogClosed = function(e:DialogEvent) {
            if ( e.button == DialogButton.SAVE ) {
                currentConfig.name = renameDialog.getDialogValue();
                configDropdown.text = currentConfig.name;
                configDropdown.selectedItem.text = currentConfig.name;
                configs[configDropdown.selectedIndex].name = currentConfig.name; // idk why this is necessary? once I added file i/o it became a mess
                refreshConfigList();
            }
        };
        renameDialog.rename.text = currentConfig.name;
        renameDialog.showDialog();
    }

    @:bind( configDropdown, UIEvent.BEFORE_CHANGE )
    function onConfigPreDropdown(e) {
        if ( configDropdown.selectedIndex >= 0 && configDropdown.selectedIndex < configs.length && configs.length > 0)
            saveConfig( configs[configDropdown.selectedIndex] );
    }

    @:bind( configDropdown, UIEvent.CHANGE )
    function onConfigDropdown(e) {
        var index = configDropdown.selectedIndex;
        loadConfig( index >= 0 ? configs[index] : null );
    }

    @:bind( buttonNewConfig, MouseEvent.CLICK )
    function addNewConfig(e:MouseEvent) {
		makeNewConfig();
        loadConfig(currentConfig);
    }

    function loadFromFileIfExists() {
        if ( !FileSystem.exists(Main.BASE_DIR + CONFIG_FILENAME) ) {
            currentData = { currentIndex: -1, configs: new Array<ConfigData>() };
            return;
        }

        var json = sys.io.File.getContent( Main.BASE_DIR + CONFIG_FILENAME );
        currentData = Json.parse(json);
        if ( currentData.currentIndex >= 0 && currentData.currentIndex < currentData.configs.length ) {
            currentConfig = currentData.configs[currentData.currentIndex];
            configDropdown.selectedIndex = currentData.currentIndex;
        }
        if ( currentConfig != null)
            lastGoodConfig = currentConfig;
        refreshConfigList();
    }

    function loadConfig(cfg:ConfigData) {
        if ( cfg == null) {
            fieldEngine.text = fieldMods.text = fieldPak0.text = fieldPak1.text = "";
            currentConfig = null;
            refreshValidate(null);
            return;
        }

        // trace("loadConfig: " + cfg);
        disableAutoRefresh = true;
        fieldEngine.text = cfg.quakeEnginePath;
        fieldMods.text = cfg.modFolderPath;
        fieldPak0.text = cfg.pak0path;
        fieldPak1.text = cfg.pak1path;
        disableAutoRefresh = false;

        currentConfig = cfg;
        refreshValidate(null);
    }


    function saveConfig(cfg:ConfigData) {
        if ( cfg == null) return;

        cfg.quakeEnginePath = fieldEngine.text;
        cfg.modFolderPath = fieldMods.text;
        cfg.pak0path = fieldPak0.text;
        cfg.pak1path = fieldPak1.text;
        if ( !configs.contains(cfg) ) {
            configs.push(cfg);
            trace("Config wasn't in the data array? uhh this shouldn't happen but trying to fix it anyway");
        }

        currentData.currentIndex = configDropdown.selectedIndex;
        var json = Json.stringify(currentData, null, "\t");
        sys.io.File.saveContent(Main.BASE_DIR + CONFIG_FILENAME, json);
    }

    public static function validateConfig(config:ConfigData) {
        if ( !isValidFile(config.quakeEnginePath, ".exe") )
            return false;

        if ( !isValidFolder(config.modFolderPath) )
            return false;

        if ( !isValidFile(config.pak0path, ".pak") || !isFileInPath(config.pak0path, config.modFolderPath) ) 
            return false;

        if ( !isValidFile(config.pak1path, ".pak") || !isFileInPath(config.pak1path, config.modFolderPath) )
            return false;

        if( isValidFile(config.quakeEnginePath, ".exe") && isQuakeEX(config.quakeEnginePath) )
            return validateForQuakeEX(config);

        return true;
    }

    public static function isQuakeEX(quakeExePath:String) {
        return quakeExePath.toLowerCase().contains("quake_x64");
    }

    public static function validateForQuakeEX(config:ConfigData):Bool {
        if ( !isValidFile(config.quakeEnginePath, ".exe") )
            return false;

        var quakeFolderPath = Path.directory(config.quakeEnginePath);
        if ( !isValidFolder(config.modFolderPath) || !isFileInPath(config.modFolderPath, quakeFolderPath) ) {
            return false;
        }

        return true;
    }

    var disableAutoRefresh = false;

    @:bind( fieldEngine, UIEvent.PROPERTY_CHANGE )
    @:bind( fieldMods, UIEvent.PROPERTY_CHANGE )
    @:bind( fieldPak0, UIEvent.PROPERTY_CHANGE )
    @:bind( fieldPak1, UIEvent.PROPERTY_CHANGE )
    function refreshValidate(e) {
        if (disableAutoRefresh)
            return;

        // needs an active config selected
        if ( currentConfig == null) {
            configForm.hide();
            configBottom.hide();
            buttonDeleteConfig.hide();
            buttonRenameConfig.hide();
            return;
        }
        configForm.show();
        buttonDeleteConfig.show();
        buttonRenameConfig.show();

        // now validate actual config settings
        var validConfig = true;
        var needsRefresh = false;

        if ( isValidFile(fieldEngine.text, ".exe") ) {
            if ( currentConfig.quakeEnginePath != fieldEngine.text ) {
                currentConfig.quakeEnginePath = fieldEngine.text;
            }
            // if the EXE path just became newly valid, then auto-fill remaining empty fields (assuming they're valid)
            if ( fieldEngine.borderColor.r > 0.5 ) {
                var quakePath = Path.addTrailingSlash(Path.normalize(Path.directory(fieldEngine.text)));
                if ( isStringEmpty(currentConfig.modFolderPath) && isStringEmpty(fieldMods.text) ) {
                    currentConfig.modFolderPath = quakePath;
                    needsRefresh = true;
                }
                if ( isStringEmpty(currentConfig.pak0path) && isStringEmpty(fieldPak0.text) ) {
                    if ( FileSystem.exists(quakePath + "id1/pak0.pak") ) {
                        currentConfig.pak0path = quakePath + "id1/pak0.pak";
                        needsRefresh = true;
                    }
                }
                if ( isStringEmpty(currentConfig.pak1path) && isStringEmpty(fieldPak1.text) ) {
                    if ( FileSystem.exists(quakePath + "id1/pak0.pak") && isQuakeEX(fieldEngine.text) ) { // KexQuake only has one pak
                        currentConfig.pak1path = quakePath + "id1/pak0.pak";
                        needsRefresh = true;
                    } else if ( FileSystem.exists(quakePath + "id1/pak1.pak") ) {
                        currentConfig.pak1path = quakePath + "id1/pak1.pak";
                        needsRefresh = true;
                    }
                }
            }
            fieldEngine.borderColor = "black";
        } else {
            fieldEngine.borderColor = "red";
            validConfig = false;
        }

        if ( isValidFolder(fieldMods.text) ) {
            if ( currentConfig.modFolderPath != fieldMods.text ) {
                currentConfig.modFolderPath = fieldMods.text;
            }
            if (fieldEngine.borderColor.r < 0.5 && isQuakeEX(currentConfig.quakeEnginePath) ) { // QuakeEX *must* use the EXE folder
                if ( !isFileInPath(currentConfig.modFolderPath, Path.directory(currentConfig.quakeEnginePath)) ) {
                    warningKex.show();
                    validConfig = false;
                } else {
                    warningKex.hide();
                }
            }
            fieldMods.borderColor = "black";
        } else {
            fieldMods.borderColor = "red";
            validConfig = false;
        }

        if ( isValidFile(fieldPak0.text, ".pak") ) {
            if ( currentConfig.pak0path != fieldPak0.text )
                currentConfig.pak0path = fieldPak0.text;

            if ( fieldMods.borderColor.r < 0.5) { // both pak path + mod path is valid
                if ( !isFileInPath(currentConfig.pak0path, currentConfig.modFolderPath) ) { // but PAK isn't in there
                    warningPak0.show();
                    validConfig = false;
                } else {
                    warningPak0.hide();
                }
            }
            fieldPak0.borderColor = "black";
        } else {
            fieldPak0.borderColor = "red";
            validConfig = false;
            warningPak0.hide();
        }

        if ( isValidFile(fieldPak1.text, ".pak")  ) {
            if ( currentConfig.pak1path != fieldPak1.text )
                currentConfig.pak1path = fieldPak1.text;

            if ( fieldMods.borderColor.r < 0.5) { // both pak path + mod path is valid
                if ( !isFileInPath(currentConfig.pak1path, currentConfig.modFolderPath) ) { // but PAK isn't in there
                    warningPak1.show();
                    validConfig = false;
                } else {
                    warningPak1.hide();
                }
            }
            fieldPak1.borderColor = "black";
        } else {
            fieldPak1.borderColor = "red";
            validConfig = false;
            warningPak1.hide();
        }

        if ( needsRefresh ) {
            currentConfig.quakeEnginePath = fieldEngine.text;
            loadConfig(currentConfig);
        }

        configBottom.hidden = !(currentConfig != null && validConfig && validateConfig(currentConfig));
    }

    static function isValidFile(path:String, extension:String):Bool {
        return path != null && path.toLowerCase().endsWith(extension) && FileSystem.exists(path);
    }

    static function isValidFolder(path:String):Bool {
        return path != null && FileSystem.exists(path) && FileSystem.isDirectory(path);
    }

    static function isFileInPath(file:String, path:String) {
        return cleanPath(file).startsWith(cleanPath(path));
    }

    @:bind( buttonConfigTest, MouseEvent.CLICK )
    function launchTest(e) {
        var testLaunch = Launcher.launch(null, null, currentConfig.modFolderPath, currentConfig.quakeEnginePath, true);
        if ( !testLaunch ) {
            trace("test launch failed! something is wrong");
        }
    }

    @:bind( buttonConfigFinish, MouseEvent.CLICK )
    function finishConfig(e) {
        saveConfig(currentConfig);
        lastGoodConfig = currentConfig;
        trace("using config: " + lastGoodConfig);
        if ( !Main.startupDone ) {
            Main.continueStartupForRealNoSeriously();
        }
        hide();
    }

    @:bind( warningKexButton, MouseEvent.CLICK )
    function fixKex(e) {
        var path = cleanPath(Path.directory(currentConfig.quakeEnginePath));
        disableAutoRefresh = true;
        fieldMods.text = path;
        fieldPak0.text = path + "id1/pak0.pak";
        fieldPak1.text = path + "id1/pak0.pak";
        disableAutoRefresh = false;
        refreshValidate(null);
    }

    @:bind( warningPak0Button, MouseEvent.CLICK )
    function copyPak0(e) {
        var path = cleanPath(currentConfig.modFolderPath) + "id1/";
        if ( !FileSystem.exists(path) ) {
            FileSystem.createDirectory(path);
        }
        var pak = hx.files.File.of(currentConfig.pak0path);
        fieldPak0.text = FileSystem.exists(path+"pak0.pak") ? path+"pak0.pak" : pak.copyTo(path+"pak0.pak").path.toString();
        refreshValidate(null);
    }

    @:bind( warningPak1Button, MouseEvent.CLICK )
    function copyPak1(e) {
        var path = cleanPath(currentConfig.modFolderPath) + "id1/";
        if ( !FileSystem.exists(path) ) {
            FileSystem.createDirectory(path);
        }
        var pak = hx.files.File.of(currentConfig.pak1path);
        fieldPak1.text = FileSystem.exists(path+"pak1.pak") ? path+"pak1.pak" : pak.copyTo(path+"pak1.pak").path.toString();
        refreshValidate(null);
    }

    static inline function isStringEmpty(testString:String) {
        return testString == null || testString.trim().length == 0;
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

    @:bind( buttonScan, MouseEvent.CLICK )
    function startQuakeScan(e) {
        scanForQuakeFiles();
        var foundQuake = quakePathsFound != null && quakePathsFound.length > 0;
        generateSelect( menuModsSelect, quakePathsFound, "Mod Folders" );
        var foundEngine = quakeEnginesFound != null && quakeEnginesFound.length > 0;
        generateSelect( menuEngineSelect, quakeEnginesFound, "Engines" );
        var foundPak0 = quakePak0sFound != null && quakePak0sFound.length > 0;
        generateSelect( menuPak0Select, quakePak0sFound, "Paks" );
        var foundPak1 = quakePak1sFound != null && quakePak1sFound.length > 0;
        generateSelect( menuPak1Select, quakePak1sFound, "Paks" );

        buttonScan.text = "FOUND " + (menuEngineSelect.dataSource.size + menuPak0Select.dataSource.size + menuPak1Select.dataSource.size) + " QUAKE FILES";
        if ( foundQuake && foundEngine && foundPak0 && foundPak1 ) {
            buttonAutoConfig.show();
        } else {
            buttonScan.text += "... BUT NOT ENOUGH TO AUTO CONFIG, SORRY";
            buttonAutoConfig.hide();
        }
    }

    public static function scanForQuakeFiles() {
        trace("beginning Quake scan...");
        var possibleQuakePaths = new Array<String>();
        possibleQuakePaths.push( Main.PROGRAM_DIR + Main.ENGINE_QUAKESPASM_PATH );
        possibleQuakePaths.push( Path.addTrailingSlash(Main.BASE_DIR + Main.INSTALL_PATH) );
        quakePathsFound = new Array<String>();
        quakeEnginesFound = new Array<String>();
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
                quakePathsFound.push( path );
                trace("found Quake path " + path);
                var listOfExes = FileSystem.readDirectory(path).filter( filepath -> filepath.toLowerCase().endsWith(".exe"));
                for(exeName in listOfExes) {
                    for( enginePrefix in quakeEnginePrefixes ) {
                        if ( exeName.toLowerCase().startsWith(enginePrefix) ) {
                            quakeEnginesFound.push( Path.normalize( Path.addTrailingSlash(path) + exeName) );
                            trace("found Quake engine " + exeName);
                            break;
                        }
                    }
                }

                var possiblePakLocations = ["/id1/pak0.pak", "/id1/pak1.pak" ];
                for( pakPath in possiblePakLocations) {
                    if (FileSystem.exists(path + pakPath) ) {
                        if ( pakPath.contains("pak0") ) {
                            quakePak0sFound.push( Path.normalize(path + pakPath) );
                        } else {
                            quakePak1sFound.push( Path.normalize(path + pakPath) );
                        }
                        trace("found " + Path.normalize(path + pakPath) );
                    }
                }

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
        if ( !pathArray.contains(path) ) {
		    pathArray.push(path);
            pathArray.push(Path.addTrailingSlash(path) + Path.addTrailingSlash("rerelease")); // look for new 2021 rerelease too
        }
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
    var currentIndex:Int;
    var configs: Array<ConfigData>;
}

typedef ConfigData = {
    var name:String;
    var quakeEnginePath:String;
    var modFolderPath:String;
    var pak0path:String;
    var pak1path:String;
}