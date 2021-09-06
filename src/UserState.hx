package ;

import json2object.JsonParser;
import datetime.DateTime;
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
            mapComplete: new Array<String>(),
            mapActivity: new Map<String, UserActivity>(),
            overrideLaunchArguments: new Map<String, String>(),
            overrideInstallFolder: new Map<String, String>()
        }
    }

    public function moveMapToFrontOfQueue(mapID:String) {
        if ( currentData.mapQueue.contains(mapID) ) {
            currentData.mapQueue.remove(mapID);
        }
        currentData.mapQueue.unshift(mapID);
        MainView.instance.refreshQueue();
    }

    public function queueMap(mapID:String) {
        if ( !currentData.mapQueue.contains(mapID) ) {
            currentData.mapQueue.push(mapID);
            Downloader.instance.queueMapDownload( Database.instance.db[mapID] );
            // Notify.instance.addNotify(mapID, "QUEUED FOR DOWNLOAD AND INSTALL:\n" + Database.instance.db[mapID].title );
            MainView.instance.refreshQueue();
            setActivity(mapID, ActivityType.Queued);
        }
        saveUser();
    }

    public function dequeueMap(mapID:String) {
        if ( currentData.mapQueue.contains(mapID) ) {
            currentData.mapQueue.remove(mapID);
            Overlay.notify(mapID, "REMOVED FROM QUEUE:\n" + Database.instance.db[mapID].title );
            MainView.instance.refreshQueue();
        }
        saveUser();
    }

    public function markMap(mapID:String) {
        if ( !currentData.mapComplete.contains(mapID) )
            currentData.mapComplete.push(mapID);
        Overlay.notify(mapID, "MARKED AS DONE:\n" + Database.instance.db[mapID].title );
        saveUser();
    }

    public function isMapQueued(mapID:String):Bool {
        return currentData.mapQueue.contains(mapID);
    }

    public function isMapCompleted(mapID:String):Bool {
        return currentData.mapComplete.contains(mapID);
    }

    public function setActivity(mapID:String, activity:ActivityType) {
        currentData.mapActivity.set(mapID, {timestamp: DateTime.local().toString(), activity: activity });
        saveUser();
    }

    public function setOverrideInstall(mapID:String, overrideName:String) {
        currentData.overrideInstallFolder.set(mapID, overrideName);
        saveUser();
    }

    public function clearOverrideInstall(mapID:String) {
        if ( currentData.overrideInstallFolder.exists(mapID) )
            currentData.overrideInstallFolder.remove(mapID);
        saveUser();
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
        var parser = new JsonParser<UserData>();
        var newData:UserData = parser.fromJson(fileData, filename);
        return newData;
    }

    public static function saveUser(?userData:UserData) {
        if ( userData == null )
            userData = UserState.instance.currentData;

        var username = userData.username; // TODO: sanitize user name for safety?
        if (!FileSystem.exists(Main.BASE_DIR + USER_DIR))
            FileSystem.createDirectory(Main.BASE_DIR + USER_DIR);

        var fileData = Json.stringify(userData, null, "\t");
        File.saveContent(Main.BASE_DIR + USER_DIR + username + ".json", fileData);
    }
}

typedef UserData = {
    var username: String;
    var mapQueue: Array<String>;
    var mapComplete: Array<String>;

    /** just a reminder for what the user last did, but interally we don't actually expect it to be accurate or reliable... key = map ID **/
    var mapActivity: Map<String, UserActivity>;

    /** overrides for what mod folder name to use... key = map ID, value = mod folder name **/
    var overrideInstallFolder: Map<String, String>;

    /** overrides for what launch arguments to use... key = map ID, value = full launch argument string **/
    var overrideLaunchArguments: Map<String, String>;
}

typedef UserActivity = {
    var timestamp: String; // DateTime string?
    var activity: ActivityType;
}

enum abstract ActivityType(String) {
    var Queued;
    var Installed;
    var Played;
}