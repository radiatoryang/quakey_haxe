package;

import haxe.Json;
import haxe.Timer;
import haxe.Http;
import haxe.io.Path;
import haxe.display.Display.Package;
import haxe.zip.Entry;
import haxe.io.BytesInput;
import Database.MapEntry;
import haxe.ui.ToolkitAssets;
import sys.FileSystem;
import sys.io.File;
import sys.thread.ElasticThreadPool;
import format.tools.MD5;
import format.zip.Reader;

import hxd.res.Loader;
import haxe.ui.backend.heaps.TileCache;
import hx.files.Dir;

using StringTools;

class Downloader {
    public static var instance:Downloader;
    
    // download requests (images, files) are queued as jobs for thread pools, to avoid blocking the main application thread
    var downloadThreadPool: ElasticThreadPool; // ZIP files
    var threadPool: ElasticThreadPool; // XML,  images
    var localLoader:Loader;
    var refreshTimer:Timer;

    var currentMapDownload: HttpQuakey;
    public var currentMapDownloadID(default, null):String;

    public static function init() {
        instance = new Downloader();
    }

    private function new() {
        downloadThreadPool = new ElasticThreadPool(1, 5.0);
        threadPool = new ElasticThreadPool(3, 5.0); 
        localLoader = new hxd.res.Loader( new hxd.fs.LocalFileSystem(Main.BASE_DIR, "") );

        refreshTimer = new Timer(1000);
        refreshTimer.run = refresh;
    }

    function refresh() {
        if (currentMapDownloadID != null && currentMapDownloadID.length > 0) { 
            var state = Database.instance.refreshState(currentMapDownloadID); 
            updateStatusBar("downloading " + Database.instance.db[currentMapDownloadID].title + " (" + Std.string(Math.round(state.downloadProgress * 100)) + "%)");
        }
    }

    function updateStatusBar(newStatus:String = "") {
        MainView.instance.menuBarStatus.text = newStatus;
    }

    static inline function getFullPath(localPath:String) {
        // TODO: account for Windows vs. other file systems?
        return Main.BASE_DIR + localPath.replace("/", "\\");
    }

    public function queueAllMapDownloads(mapIDs:Array<String>) {
        for( mapID in mapIDs) {
            var mapData = Database.instance.db[mapID];
            queueMapDownload( mapData );
        }
    }

    public function queueMapDownload(mapData:MapEntry, ?mapIDToTryToInstall:String) {
        // download dependencies too
        if ( mapData.techinfo != null && mapData.techinfo.requirements != null) {
            for( dependencyID in mapData.techinfo.requirements ) {
                if ( Database.instance.db.exists(dependencyID) ) {
                    var depend = Database.instance.db[dependencyID];
                    if ( mapIDToTryToInstall == null) {
                        mapIDToTryToInstall = mapData.id; // don't try to install dependencies as standalones
                    }
                    queueMapDownload( depend, mapIDToTryToInstall );
                } else {
                    trace( 'ERROR! cannot find requirement with ID:$dependencyID -- this is a problem in the XML, please tell Quaddicted to fix this!');
                }
            }
        }
        
        if ( !isMapDownloaded(mapData.id) ) {
            var notifyMessage = "QUEUED FOR DOWNLOAD: " + mapData.title;
            if ( mapIDToTryToInstall != null) {
                var mainPackage = Database.instance.db[mapIDToTryToInstall];
                notifyMessage += " (required for " + mainPackage.title + ")";
            }
            Notify.instance.addNotify(mapData.id, notifyMessage);
            downloadThreadPool.run( () -> { downloadMapAsync(mapData.id, mapData.md5sum, mapIDToTryToInstall); } );
        } else {
            trace( 'map ' + mapData.id + ' was already downloaded');

            if ( mapIDToTryToInstall == null) // if this isn't a dependency, then try to install it now
                queueMapInstall( mapData, true );
        }
    }

    /** returns true if .zip file is in the downloads folder **/
    public static function isMapDownloaded(mapID:String):Bool {
        return FileSystem.exists( getMapDownloadPath(mapID) );
    }

    public static function getMapDownloadPath(mapID:String) {
        return getFullPath(Main.DOWNLOAD_PATH + "/" + mapID + ".zip");
    }

    function downloadMapAsync(mapID:String, expectedMd5:String, ?mapIDToTryToInstall:String) {
        if ( isMapDownloaded(mapID) ) {
            Main.mainThread.events.run( () -> { onDownloadMapSuccess(mapID, mapIDToTryToInstall); } );
            return;
        }

        if ( UserState.instance.isMapQueued(mapID) == false && (mapIDToTryToInstall == null || UserState.instance.isMapQueued(mapIDToTryToInstall) == false)) {
            trace( (mapIDToTryToInstall != null ? mapIDToTryToInstall : mapID) + " was removed from queue, so canceling download " + mapID);
            return;
        }

        trace('started downloading $mapID');
        var fullPath = getFullPath(Main.DOWNLOAD_PATH + "/" + mapID + ".zip");
        var url = "https://www.quaddicted.com/filebase/" + mapID + ".zip";
        currentMapDownloadID = mapID;
        // Main.mainThread.events.run( () -> { MainView.instance.refreshAllMapButtons(); } );
        currentMapDownload = new HttpQuakey(url);
        currentMapDownload.onBytes = function(bytes) { 
            var md5 = MD5.make(bytes).toHex();
            if ( md5 != expectedMd5 ) {
                Notify.instance.addNotify(mapID, "error: file was corrupted for " + Database.instance.db[mapID].title );
                return;
            }

            File.saveBytes(fullPath, bytes);
            currentMapDownload.currentOutput.flush();
            currentMapDownload.currentOutput.close();
            trace('successfully downloaded $mapID to $fullPath !');
            Main.mainThread.events.run( () -> { onDownloadMapSuccess(mapID, mapIDToTryToInstall); } );
        }
        currentMapDownload.onError = function(status) { 
            Main.mainThread.events.run( () -> { onDownloadMapError(mapID, status); } );
        }
        currentMapDownload.request();
    }

    public function onDownloadMapSuccess(mapID:String, ?mapIDToTryToInstall:String, suppressNotification:Bool=false) {
        currentMapDownloadID = "";
        if (!suppressNotification)
            Notify.instance.addNotify(mapID, "finished downloading " + Database.instance.db[mapID].title);
        Database.instance.refreshState(mapID);

        queueMapInstall( Database.instance.db[mapIDToTryToInstall != null ? mapIDToTryToInstall : mapID], mapIDToTryToInstall == null );
    }

    public function onDownloadMapError(mapID:String, error:String) {
        currentMapDownloadID = "";
        Notify.instance.addNotify(mapID, 'network error $error downloading ' + Database.instance.db[mapID].title );
        Database.instance.refreshState(mapID);
    }

    /** returns -1 if no download, or 0.0-1.0 if there is a map download in progress **/
    public function getCurrentMapDownloadProgress():Float {
        if ( currentMapDownload == null || currentMapDownloadID == null || currentMapDownloadID == "" ) {
            return -1;
        }

        var totalBytes = Database.instance.db[currentMapDownloadID].size * 1000000; 
        var currentBytes = currentMapDownload.currentOutput.length;

        return (currentBytes / totalBytes);
    }

    public static function isModInstalled(mapID:String) {
        var mapData = Database.instance.db[mapID];
        var installPath = getModInstallFolder(mapData);
        if ( FileSystem.exists(installPath) ) {
            var files = Dir.of(installPath);
            return !files.isEmpty(); // no files inside (unzip operation failed?)
        } else {
            return false; // no folder found
        }
    }

    /** returns the FULL PATH to the mod install folder **/
    public static function getModInstallFolder(mapData:MapEntry, ?installPathOverride:String) {
        if ( installPathOverride == null)
            installPathOverride = Path.addTrailingSlash(Config.instance.lastGoodConfig.modFolderPath);
        //    installPathOverride = Main.BASE_DIR + Path.addTrailingSlash(Main.INSTALL_PATH);
        //    installPathOverride = UserState.instance.currentData.quakeExePath;

        return Path.addTrailingSlash( Path.directory(installPathOverride) ) + Path.addTrailingSlash(getModInstallFolderName(mapData)); 
        // return UserState.instance.currentData.quakePath + "/quakey_" + getDesiredModFolder(mapData);
    }

    public static function getModInstallFolderName(mapData:MapEntry) {
        // we repackage all quakey mods with "quakey_" prefix to avoid breaking Quake installations or anything
        // the process for deciding what folder to put the mapData in:
        // 1. TODO: manual user override for where to put it
        // 2. use mapID as suffix
        // 3. or for max compatibility you can use getModInstallFolderSuffix to know what mod it expected to use

        return "quakey_" + mapData.id.replace(".", "-").replace(" ", "");
    }

    public static function getDesiredModFolder(mapData:MapEntry) {
        // process for figuring out the desired mod folder
        // 1. look for any "-game" command line ... this is good for most modern Quake packages (what most people will play)
        // 2. then check the zipbasedir .. this is good for most old map packs (1000+ items) that all use "id1/maps/"
        // 3. TODO: if both of those fail, then do this the hard way -- scan the .zip and look for root folder of any .dat or .pak or .bsp

        // this process must be deterministic and reliable

        // the original idea was to just install everything in its own folder?
        // but we have to do this complicated process because some Quaddicted packages can go together
        // even though they're not always marked-up as "requirements" in the XML
        // and the only way you know they go together is if they just happen to share the same root mod folder
        
        var desiredModFolder:String = null;
        var zipBaseDir = "";
        var foundGoodRoot = false;
        // trace('getModInstallFolderSuffix for $installSuffix ...');

        if ( mapData.techinfo != null ) {
            // first, look for a "-game" commandline, e.g. "-game copper" but also possibly like "-hipnotic -game actualModName"
            if (mapData.techinfo.commandline != null && mapData.techinfo.commandline.contains("-game")) {
                var cmdLineClean = mapData.techinfo.commandline.trim();
                // trace('getModInstallFolderSuffix scanning for gamedir in $cmdLineClean ...');
                while ( cmdLineClean.contains("  ") ) { // take no chances with extra whitespace
                    cmdLineClean = cmdLineClean.replace("  ", " ");
                }
                var cmdLineParts = cmdLineClean.split(" ");
                for ( i in 0...cmdLineParts.length) {
                    if (cmdLineParts[i].contains("-game") && cmdLineParts.length > i+1 && cmdLineParts[i+1].trim().length > 0) {
                        desiredModFolder = cmdLineParts[i+1].trim();
                        foundGoodRoot = true;
                        break;
                    }
                }
            }
            // second, look for a zipbasedir ... e.g. "id1/maps/" or "/id1/maps" or "id1/" or "copper" etc.
            else if (mapData.techinfo.zipbasedir != null && mapData.techinfo.zipbasedir.replace("/", "").trim().length > 0) {
                var zipClean = mapData.techinfo.zipbasedir.trim();
                // trace('getModInstallFolderSuffix scanning for gamedir in $zipClean ...');
                zipClean = zipClean.replace(" ", "").replace("\\", "/"); // take no chances with white space or slashes
                while ( zipClean.startsWith("/") ) {
                    zipClean = zipClean.substr(1); // no slash at the beginning
                }
                var zipCleanParts = zipClean.split("/");
                for( part in zipCleanParts ) {
                    if ( part != "maps" && part.length > 0 ) {
                        desiredModFolder = part;
                        foundGoodRoot = true;
                        break;
                    }
                }
            }
            // if both of those methods above failed, we can also look at the command line switch
            else if ( mapData.techinfo.commandline != null && mapData.techinfo.commandline.contains("-nehahra") ) {
                desiredModFolder = "nehahra";
                foundGoodRoot = true;
            }
            else if ( mapData.techinfo.commandline != null && mapData.techinfo.commandline.contains("-quoth") ) {
                desiredModFolder = "quoth";
                foundGoodRoot = true;
            }
            else if ( mapData.techinfo.commandline != null && mapData.techinfo.commandline.contains("-hipnotic") ) {
                desiredModFolder = "hipnotic";
                foundGoodRoot = true;
            }
        }

        // try the hard way, and scan the .zip for a desired mod folder... e.g. gsh_tod, soeskins_glquake
        if ( !foundGoodRoot && isMapDownloaded(mapData.id) ) {
            var embeddedRoot = getRootModFolderInZipIfAny( getMapDownloadPath(mapData.id) );
            if ( embeddedRoot != null && embeddedRoot.replace("/", "").trim().length > 0 ) {
                if ( embeddedRoot.indexOf("/") < embeddedRoot.length - 1 ) { 
                    // trace("(holy shit, the mod folder is nested inside ANOTHER folder(s)??)");
                    var parts = embeddedRoot.split("/");
                    var lastPart = parts[parts.length-1];
                    if ( lastPart != null && lastPart.trim().length > 0) {
                        desiredModFolder = lastPart.trim();
                        foundGoodRoot = true;
                    }
                }
            }
        }

        // trace('getModInstallFolderSuffix for ' + mapData.id + ' is $installSuffix ... foundGoodSuffix: $foundGoodSuffix');
        return desiredModFolder;
    }

    public function queueMapInstall(mapData:MapEntry, canQueueDownload:Bool=false, installEvenIfAlreadyInstalled:Bool=false) {
        if ( !installEvenIfAlreadyInstalled ) {
            if ( isModInstalled(mapData.id) ) {
                trace(mapData.id + " was already installed!");
                return;
            }
        }

        // before we do anything, let's make sure we downloaded all dependencies... if we haven't, we need to stop and queue this installation for later

        // TODO: also search command lines for possible dependencies?
        if ( mapData.techinfo != null && mapData.techinfo.requirements != null && mapData.techinfo.requirements.length > 0) {
            for( req in mapData.techinfo.requirements) {
                if ( !Downloader.isMapDownloaded(req) ) {
                    if ( canQueueDownload )
                        queueMapDownload(mapData);
                    trace("can't install " + mapData.id + " yet, still need to download dependency " + req);
                    return;
                }
            }
        }
        downloadThreadPool.run( () -> { installModAsync( mapData ); } );
    }

    public function installModAsync(mapData:MapEntry) {
        updateStatusBar("installing " + mapData.title + "...");
        try {
            // if no template folder found, need to help user troubleshoot and set TEMPLATE_PATH?
            // if ( !FileSystem.exists(getFullPath(Main.TEMPLATE_PATH) )) {
            //     Notify.instance.addNotify( mapData.id, "no Quake folder template was found at " + getFullPath(Main.TEMPLATE_PATH) + " so can't install " + mapData.title);
            //     return;
            // }
            trace("installing " + mapData.id);

            var newInstallFolder = getModInstallFolder(mapData); // this function takes all user preferences etc. into account

            if ( !FileSystem.exists(newInstallFolder))
                FileSystem.createDirectory( newInstallFolder );
            var newMapsFolder = newInstallFolder + "maps/";
            if ( !FileSystem.exists(newMapsFolder))
                FileSystem.createDirectory( newMapsFolder );

            var unzipRoot = newInstallFolder;

            // copy over template files
            // var templateDir = Dir.of( getFullPath(Main.TEMPLATE_PATH));
            // templateDir.copyTo(newInstallFolder, [DirCopyOption.OVERWRITE, DirCopyOption.MERGE]);
            // trace("successfully copied mod base template files over to " + newInstallFolder);

            // unzip all dependencies
            if ( mapData.techinfo != null && mapData.techinfo.requirements != null && mapData.techinfo.requirements.length > 0) {
                for( req in mapData.techinfo.requirements) {
                    if ( Downloader.isMapDownloaded(req)) {
                        unzip( getFullPath( Path.addTrailingSlash(Main.DOWNLOAD_PATH) + req + ".zip"), unzipRoot, Database.instance.db[req] );
                    }
                }
            }

            // unzip actual mod now
            unzip( getFullPath( Path.addTrailingSlash(Main.DOWNLOAD_PATH) + mapData.id + ".zip"), unzipRoot, mapData );
            trace("successfully unzipped " + mapData.id + " to " + unzipRoot );

            // write mapdb.json for KexQuake (or any other engine after it)
            var mapManifest = getMapManifest(mapData);
            var mapManifestJson = Json.stringify(mapManifest, null, "    ");
            File.saveContent( Path.addTrailingSlash(newInstallFolder) + "mapdb.json", mapManifestJson );

            Main.mainThread.events.run( () -> { onInstallMapSuccess(mapData.id); } );
        } catch (e) {
            Main.mainThread.events.run( () -> { onInstallMapError(mapData.id, e.message); } );
            throw e;
        }
    }

    public function onInstallMapSuccess(mapID:String) {
        updateStatusBar();
        Notify.instance.addNotify(mapID, "finished installing " + Database.instance.db[mapID].title);
        Database.instance.refreshState(mapID);
    }

    public function onInstallMapError(mapID:String, error:String) {
        updateStatusBar();
        Notify.instance.addNotify(mapID, 'install error ($error) ' + Database.instance.db[mapID].title );
        Database.instance.refreshState(mapID);
    }

    public static function unzip(zipFilePath:String, localUnzipPath:String, mapData:MapEntry, tryToRepackageToRoot:Bool=true) {
        // if package is meant to be unzipped to /maps/ based on XML data?
        var zipBaseDir = mapData.techinfo != null ? mapData.techinfo.zipbasedir : null;
        if ( zipBaseDir != null && zipBaseDir.contains("maps") ) {
            localUnzipPath += Path.addTrailingSlash("maps");
        }

        // trace("beginning to unzip " + zipFilePath);
        var zipfileBytes = File.getBytes(zipFilePath);
        var bytesInput = new BytesInput(zipfileBytes);
        var reader = new Reader(bytesInput);
        var entries:List<Entry> = reader.read();

        var finalUnzipPath = new Map<String, String>();
        for( _entry in entries) {
            finalUnzipPath.set(_entry.fileName, _entry.fileName);
        }
        // trace("ZIP file entries found!");

        // repackage phase: if the ZIP packaged its own embedded mod folder, we have to move all files up one level
        if ( tryToRepackageToRoot ) {
            var embeddedModFolder = getRootModFolderInZipIfAny(zipFilePath, entries);
            if ( embeddedModFolder != null && embeddedModFolder.replace("/", "").trim().length > 0 ) {
                for( key => value in finalUnzipPath) {
                    if (key.startsWith(embeddedModFolder)) {
                        finalUnzipPath[key] = value.substr(embeddedModFolder.length);
                    }
                }
            }
        }
        // trace("repackage check done!");

        // actually unzip now
        for (_entry in entries) {
            var data = Reader.unzip(_entry);
            if (_entry.fileName.substring(_entry.fileName.lastIndexOf('/') + 1) == '' && _entry.data.toString() == '') {
                sys.FileSystem.createDirectory(localUnzipPath + finalUnzipPath[_entry.fileName] );
            } else {
                try {
                    var f = File.write(localUnzipPath + finalUnzipPath[_entry.fileName], true);
                    f.write(data);
                    f.close();
                } catch(error) { // file couldn't be written to? maybe close Quake and try again
                    trace(error);
                }
            }
            // trace("unzip " + _entry.fileName + " >> " + finalUnzipPath[_entry.fileName]);
        }
        // trace("unzip complete!");

        bytesInput.close();
        return entries;
    }

    // things we'd expect to find in the game mod folder root
    static var rootSubItems:Array<String> = [ "progs.dat", "pak0.pak", "pak1.pak", "pak2.pak", "maps/", "progs/", "gfx/", "textures/", "sound/", "music/"];

    public static function getRootModFolderInZipIfAny(zipFilePath:String, ?entries:List<Entry>):String {
        if ( entries == null ) { // if no pre-existing ZIP file entries supplied, then generate our own
            var zipfileBytes = File.getBytes(zipFilePath);
            var bytesInput = new BytesInput(zipfileBytes);
            var reader = new Reader(bytesInput);
            entries = reader.read();
        }

        var rootModFolder:String = null;

        // try to find the root mod folder... look for a pak0.pak, progs.dat, or /maps/ or /progs/ folder, etc.
        for( _entry in entries ) {
            var filepath = _entry.fileName.replace("\\", "/"); // normalize
            // trace("getRootModFolderInZipIfAny is scanning " + filepath);
            for( subItem in rootSubItems ) {
                if ( filepath.contains(subItem) ) {
                    var parts = filepath.split(subItem);
                    rootModFolder = parts[0];
                    break;
                }
            }

            if ( rootModFolder != null) {
                trace("found root mod folder inside .ZIP: " + rootModFolder);
                break;
            }
        }

        return rootModFolder;
    }

    public function tryDeleteAll(mapID:String) {
        tryDeleteDownload(mapID);
        tryDeleteInstall(mapID);
    }

    public function tryDeleteDownload(mapID:String) {
        if ( isMapDownloaded(mapID) ) {
            try {
                FileSystem.deleteFile( getMapDownloadPath(mapID) );
                Notify.instance.addNotify(mapID, "deleted " + getMapDownloadPath(mapID) );
            } catch (e) {
                Notify.instance.addNotify(mapID, "couldn't delete " + getMapDownloadPath(mapID) + " (" + e.message + ")" );
            }
        } else {
            trace("tried to delete download " + mapID + ".zip but it was already deleted?");
        }
    }

    public function tryDeleteInstall(mapID:String) {
        if ( isModInstalled(mapID) ) {
            try {
                var dir = Dir.of( getModInstallFolder( Database.instance.db[mapID]) );
                dir.delete(true);
                Notify.instance.addNotify(mapID, "deleted " + getModInstallFolder( Database.instance.db[mapID]) );
            } catch (e) {
                Notify.instance.addNotify(mapID, "couldn't delete " + getModInstallFolder( Database.instance.db[mapID]) + " (" + e.message + ")" );
            }
        } else {
            trace("tried to delete install /" + getModInstallFolderName(Database.instance.db[mapID]) + "/ but it was already deleted?");
        }
    }

    public function cancelAllImageDownloads() {
        @:privateAccess while(threadPool.queue.pop(false) != null) { }
    }

    public function getImageAsync(filename:String, callback:String->Void) {
        var localPath = Path.addTrailingSlash(Main.CACHE_PATH) + filename;
        // if file is already cached, we don't need to do anything
        if ( TileCache.exists(localPath) ) {
            callback(localPath);
            return;
        }
        // otherwise, start a thread to download it
        threadPool.run( () -> { downloadImageAsync(filename, callback); } );
    }

    function downloadImageAsync(filename:String, callback:String -> Void) {
        var localPath = Path.addTrailingSlash(Main.CACHE_PATH) + filename;
        var fullPath = getFullPath(localPath);
        if ( !FileSystem.exists(fullPath) ) {
            var url = "https://www.quaddicted.com/reviews/screenshots/" + filename;
            var http = new haxe.Http(url);
            http.onBytes = function(bytes) { 
                File.saveBytes(fullPath, bytes); 
                Main.mainThread.events.run( () -> { callback(localPath); } );
                trace('saved $localPath to $fullPath');
            }
            http.onError = function(status) { 
                // TODO: queue another request later on?
                trace("error: " + status); 
            }
            http.request();
        } else {
            // callback( localPath );
            Main.mainThread.events.run( () -> { callback(localPath); } );
        }
    }

    /* returns filepath string if the image filepath is valid */
    public function allocateAndCacheImage(filepath:String) {
        // is image already cached?
        if ( TileCache.exists(filepath) ) {
            return filepath;
        }

        // double check the file exists
        if ( !localLoader.exists(filepath) ) {
            return null;
        }

        var data = localLoader.load(filepath);

        // double check the file isn't an html 
        var text = data.toText();
        if ( text.startsWith("<html>") ) {
            return null;
        }

        cacheImage(filepath, data.toImage() );

        return filepath;
    }

    function cacheImage(filepath:String, image:hxd.res.Image) {
        var imageData = { width: image.getSize().width, height: image.getSize().height, data: image.toBitmap() };
        @:privateAccess ToolkitAssets.instance._imageCache.set(filepath, imageData);
        TileCache.set(filepath, image.toTile() );
    }

    public static function getMapListFromDisk(mapData:MapEntry):Array<String> {
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

    /** generate data for mapdb.json that KexQuake / QuakeEX needs **/
    static function getMapManifest(mapData:MapEntry):MapManifest {
        var newManifest = {
            episodes: new Array<MapManifestEpisode>(),
            maps: new Array<MapManifestMap>()
        };
        
        newManifest.episodes.push( getMapManifestEpisode(mapData) );
        if ( mapData.techinfo != null && mapData.techinfo.startmap != null && mapData.techinfo.startmap.length > 0 ) {
            for( startmap in mapData.techinfo.startmap ) {
                newManifest.maps.push( getMapManifestMap(mapData, startmap) );
            }
        } else {
            // get a list of all BSPs in /maps/
            var mapNames = getMapListFromDisk(mapData);
            if ( mapNames != null) {
                for( mapName in mapNames ) {
                    newManifest.maps.push( getMapManifestMap(mapData, mapName) );
                }
            }
        }

        return newManifest;
    }

    static function getMapManifestEpisode(mapData:MapEntry):MapManifestEpisode {
        return {
            dir: getModInstallFolderName(mapData),
            name: mapData.title,
            needsSkillSelect: true
        };
    }

    static function getMapManifestMap(mapData:MapEntry, mapFileName:String):MapManifestMap {
        return {
            title: mapFileName,
            bsp: mapFileName,
            episode: getModInstallFolderName(mapData),
            game: getModInstallFolderName(mapData),
            dm: false,
            coop: false,
            bots: false,
            sp: true
        };
    }
}

/** used by KexQuake / QuakeEX re-release, output as mapdb.json in root of mod folder **/
typedef MapManifest = {
    var episodes:Array<MapManifestEpisode>;
    var maps:Array<MapManifestMap>;
}

/** used by KexQuake / QuakeEX re-release **/
typedef MapManifestEpisode = {
    /** game folder name... I think? **/
    var dir:String;

    /** proper display string in game **/
    var name:String;

    /** display skill select in UI? default to always on, because why not **/
    var needsSkillSelect:Bool;
}

/** used by KexQuake / QuakeEX re-release **/
typedef MapManifestMap = {
    /** proper display string in game**/
    var title:String;

    /** map file name, without .bsp at the end **/
    var bsp:String;

    /** same value as "game" and MapManifestEpisode dir **/
    var episode:String;

    /** same value as "episode" and MapManifestEpisode dir **/
    var game:String;

    /** does this map support deathmatch? (needs info_player_deathmatch spawns) **/
    var dm:Bool;

    /** does this map support coop? (needs info_player_coop spawns) **/
    var coop:Bool;

    /** does this map support bots? (needs .NAV files) **/
    var bots:Bool;

    /** does this map support singleplayer? (needs info_player_start) 
    ... default to true, because that's what we're here for **/
    var sp:Bool;
}