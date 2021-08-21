package ;

import haxe.io.Path;
import sys.FileSystem;
import haxe.Json;
import sys.io.File;

using StringTools;
using UnicodeString;

/** maintains different users, user settings, queued maps, etc. **/
class UserState {
    public static var instance:UserState = new UserState();
    public var currentData:UserData;

    static inline var USER_DIR = "users/";
    static inline var DEFAULT_USERNAME = "Ranger";

    public function new() {
        currentData = {
            username: DEFAULT_USERNAME,
            mapQueue: new Array<String>(),
            mapComplete: new Array<String>()
        }
    }

    public function moveMapToFrontOfQueue(mapID:String) {
        if ( currentData.mapQueue.contains(mapID) ) {
            currentData.mapQueue.remove(mapID);
        }
        currentData.mapQueue.unshift(mapID);
    }

    public function queueMap(mapID:String) {
        if ( !currentData.mapQueue.contains(mapID) ) {
            currentData.mapQueue.push(mapID);
            Downloader.instance.queueMapDownload( Database.instance.db[mapID] );
        }
        saveUser(currentData);
    }

    public function markMap(mapID:String) {
        if ( !currentData.mapComplete.contains(mapID) )
            currentData.mapComplete.push(mapID);
        // TODO: display in event log?
        saveUser(currentData);
    }

    public function isMapQueued(mapID:String):Bool {
        return currentData.mapQueue.contains(mapID);
    }

    public function isMapCompleted(mapID:String):Bool {
        return currentData.mapComplete.contains(mapID);
    }

    public static function getUsers():Array<String> {
        if (!FileSystem.exists(Main.BASE_DIR + USER_DIR))
            return null;

        var files = FileSystem.readDirectory(Main.BASE_DIR + USER_DIR);
        files.filter( file -> file.endsWith(".json"));
        return files;
    }

    public static function loadUser(filename:String) {
        var filename = Main.BASE_DIR + USER_DIR + filename;
        if ( !FileSystem.exists(filename) ) {
            trace ("couldn't find file " + filename);
            return null;
        }

        var fileData = File.getContent(filename);
        var newData:UserData = Json.parse(fileData); // TODO: exception handling?
        return newData;
    }

    public static function saveUser(userData:UserData) {
        var username = userData.username; // TODO: sanitize user name for safety?
        if (!FileSystem.exists(Main.BASE_DIR + USER_DIR))
            FileSystem.createDirectory(Main.BASE_DIR + USER_DIR);

        var fileData = Json.stringify(userData);
        File.saveContent(Main.BASE_DIR + USER_DIR + username + ".json", fileData);
    }

    public static function getQuakeEXEPath() {
        if ( instance == null)
            return null;

        if ( instance.currentData == null)
            return null;

        return instance.currentData.quakeExePath;
    }

    public static function getQuakeFolderPath() {
        if ( instance == null)
            return null;

        if ( instance.currentData == null)
            return null;
        
        return Path.directory( getQuakeEXEPath() );
    }
}

typedef UserData = {
    var username: String;
    var mapQueue: Array<String>;
    var mapComplete: Array<String>;
    var ?quakeExePath: String;
}