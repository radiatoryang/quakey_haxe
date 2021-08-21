package;

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

    public static function init() {
        instance = new Downloader();
    }

    private function new() {
        downloadThreadPool = new ElasticThreadPool(1, 5.0);
        threadPool = new ElasticThreadPool(1, 5.0); // need to keep this ThreadPool at 1 otherwise the CPU usage gets really intense
        localLoader = new hxd.res.Loader( new hxd.fs.LocalFileSystem(Main.BASE_DIR, "") );
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
            for( dependency in mapData.techinfo.requirements ) {
                if ( Database.instance.db.exists(dependency) ) {
                    if ( mapIDToTryToInstall == null) {
                        mapIDToTryToInstall = mapData.id; // don't try to install dependencies as standalones
                    }
                    trace( 'for ' + mapData.id + ', found dependency $dependency');
                    queueMapDownload( Database.instance.db[dependency], mapIDToTryToInstall );
                } else {
                    trace( 'ERROR! cannot find requirement with ID:$dependency -- this is a problem in the XML, please tell Quaddicted to fix this!');
                }
            }
        }
        
        if ( !isMapDownloaded(mapData.id) ) {
            downloadThreadPool.run( () -> { downloadMapAsync(mapData.id, mapData.md5sum, mapIDToTryToInstall); } );
            trace( 'queued ' + mapData.id + " for download");
        } else {
            // TODO: wait for a while, and then queue install again?
            trace( 'map ' + mapData.id + ' was already downloaded');

            // DEBUG -- test our unzip and install features
            // getRootModFolderInZipIfAny( getMapDownloadPath(mapID) );
            // installModAsync( mapData );
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
        if ( isMapDownloaded(mapID) )
            return;

        var fullPath = getFullPath(Main.DOWNLOAD_PATH + "/" + mapID + ".zip");
        var url = "https://www.quaddicted.com/filebase/" + mapID + ".zip";
        var http = new haxe.Http(url);
        http.onBytes = function(bytes) { 
            var md5 = MD5.make(bytes).toHex();
            if ( md5 != expectedMd5 ) {
                Notify.instance.addNotify(mapID, "error: file was corrupted for " + Database.instance.db[mapID].title );
                return;
            }

            File.saveBytes(fullPath, bytes);
            trace('successfully downloaded $mapID to $fullPath !');
            Main.mainThread.events.run( () -> { onDownloadMapSuccess(mapID, mapIDToTryToInstall); } );
        }
        http.onError = function(status) { 
            Main.mainThread.events.run( () -> { onDownloadMapError(mapID, status); } );
        }
        http.request();
    }

    public function onDownloadMapSuccess(mapID:String, ?mapIDToTryToInstall:String) {
        Notify.instance.addNotify(mapID, "finished downloading " + Database.instance.db[mapID].title);

        queueMapInstall( Database.instance.db[mapIDToTryToInstall != null ? mapIDToTryToInstall : mapID], mapIDToTryToInstall == null );
    }

    public function onDownloadMapError(mapID:String, error:String) {
        Notify.instance.addNotify(mapID, 'network error $error downloading ' + Database.instance.db[mapID].title );
    }

    public static function isModInstalled(mapID:String) {
        var mapData = Database.instance.db[mapID];
        return FileSystem.exists( getModInstallFolder(mapData) );
    }

    public static function getModInstallFolder(mapData:MapEntry, ?quakeExePath:String) {
        if ( quakeExePath == null)
            quakeExePath = UserState.instance.currentData.quakeExePath;

        return Path.addTrailingSlash( Path.directory(quakeExePath) ) + Path.addTrailingSlash(getModInstallFolderName(mapData)); 
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

    public function queueMapInstall(mapData:MapEntry, canQueueDownload:Bool=false) {
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
        // if no template folder found, need to help user troubleshoot and set TEMPLATE_PATH?
        // if ( !FileSystem.exists(getFullPath(Main.TEMPLATE_PATH) )) {
        //     Notify.instance.addNotify( mapData.id, "no Quake folder template was found at " + getFullPath(Main.TEMPLATE_PATH) + " so can't install " + mapData.title);
        //     return;
        // }

        var newInstallFolder = getModInstallFolder(mapData); // this function takes all user preferences etc. into account

        if ( !FileSystem.exists(newInstallFolder))
            FileSystem.createDirectory( newInstallFolder );
        var newMapsFolder = newInstallFolder + "maps/";
        if ( !FileSystem.exists(newMapsFolder))
            FileSystem.createDirectory( newMapsFolder );

        var unzipRoot = newInstallFolder;

        var zipBaseDir = mapData.techinfo != null ? mapData.techinfo.zipbasedir : null;
        if ( zipBaseDir != null && zipBaseDir.contains("maps") ) {
        //    trace("... must unzip this to /maps/!");
            unzipRoot = newMapsFolder;
        }

        // copy over template files
        // var templateDir = Dir.of( getFullPath(Main.TEMPLATE_PATH));
        // templateDir.copyTo(newInstallFolder, [DirCopyOption.OVERWRITE, DirCopyOption.MERGE]);
        // trace("successfully copied mod base template files over to " + newInstallFolder);

        // unzip everything
        // unzip all dependencies
        if ( mapData.techinfo != null && mapData.techinfo.requirements != null && mapData.techinfo.requirements.length > 0) {
            for( req in mapData.techinfo.requirements) {
                if ( Downloader.isMapDownloaded(req)) {
                    unzip( Path.addTrailingSlash(Main.DOWNLOAD_PATH) + mapData.id + ".zip", unzipRoot );
                }
            }
        }

        // unzip actual mod now
        unzip( getFullPath( Path.addTrailingSlash(Main.DOWNLOAD_PATH) + mapData.id + ".zip"), unzipRoot );
        trace("successfully unzipped " + mapData.id + " to " + unzipRoot );
    }

    public static function unzip(zipFilePath:String, localUnzipPath:String, tryToRepackageToRoot:Bool=true) {
        var zipfileBytes = File.getBytes(zipFilePath);
        var bytesInput = new BytesInput(zipfileBytes);
        var reader = new Reader(bytesInput);
        var entries:List<Entry> = reader.read();

        var finalUnzipPath = new Map<String, String>();
        for( _entry in entries) {
            finalUnzipPath.set(_entry.fileName, _entry.fileName);
        }

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

    public function getImageAsync(filename:String, callback:String->Void) {
        var localPath = Main.CACHE_PATH + "/" + filename;
        // if file is already cached, we don't need to do anything
        if ( TileCache.exists(localPath) ) {
            callback(localPath);
            return;
        }
        // otherwise, start a thread to download it
        threadPool.run( () -> { downloadImageAsync(filename, callback); } );
    }

    function downloadImageAsync(filename:String, callback:String -> Void) {
        var localPath = Main.CACHE_PATH + "/" + filename;
        var fullPath = getFullPath(localPath);
        if ( !FileSystem.exists(fullPath) ) {
            var url = "https://www.quaddicted.com/reviews/screenshots/" + filename;
            var http = new haxe.Http(url);
            http.onBytes = function(bytes) { 
                File.saveBytes(fullPath, bytes); 
                Main.mainThread.events.run( () -> { callback(localPath); } );
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
}