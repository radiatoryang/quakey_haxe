package ;

import sys.FileSystem;
import haxe.Json;
import sys.io.File;

using StringTools;
using UnicodeString;

/** maintains different users, user settings, queued maps, etc. **/
class UserState {
    public static var instance:UserState;
    public var currentData:UserData;

    static inline var USER_DIR = "users/";
    static inline var DEFAULT_USERNAME = "Ranger";
    static inline var DEFAULT_DOWNLOAD_DIR = "download/";

    public function new() {
        currentData = {
            username: DEFAULT_USERNAME,
            mapState: new Map<String, MapState>(),
            downloadPath: DEFAULT_DOWNLOAD_DIR
        }
    }

    public function queueMap(mapID:String) {
        var newMapState = {
            id: mapID,
            status: MapStatus.Queued,
            lastModified: Date.now()
        };
        currentData.mapState.set(mapID, newMapState);
        // TODO: display in event log?
        saveUser(currentData);
    }

    public function markMap(mapID:String) {
        var newMapState = {
            id: mapID,
            status: MapStatus.Completed,
            lastModified: Date.now()
        };
        currentData.mapState.set(mapID, newMapState);
        // TODO: display in event log?
        saveUser(currentData);
    }

    public function getMapStatus(mapID:String):MapStatus {
        return currentData.mapState.exists(mapID) ? currentData.mapState[mapID].status : null;
    }

    public function isMapCompleted(mapID:String):Bool {
        return currentData.mapState.exists(mapID) && currentData.mapState[mapID].status == MapStatus.Completed;
    }

    public static function getUsers():Array<String> {
        if (!FileSystem.exists(Main.BASE_DIR + USER_DIR))
            return null;

        var files = FileSystem.readDirectory(Main.BASE_DIR + USER_DIR);
        files.filter( file -> file.endsWith(".json"));
        return files;
    }

    public static function loadUser(username:String) {
        var filename = Main.BASE_DIR + USER_DIR + username + ".json";
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
}

typedef UserData = {
    var username: String;
    var mapState: Map<String, MapState>;
    var ?quakePath: String;
    var downloadPath: String;
}

typedef MapState = {
    var id:String;
    var status:MapStatus;
    var ?lastModified:Date;
}

enum MapStatus {
    Queued;
    Downloading;
    ReadyToPlay;
    Played;
    Completed;
}