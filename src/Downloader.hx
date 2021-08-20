package;

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

    public function queueMapDownload(mapData:MapEntry) {
        if ( !isMapDownloaded(mapData.id) ) {
            // download dependencies too
            if ( mapData.techinfo != null && mapData.techinfo.requirements != null) {
                for( dependency in mapData.techinfo.requirements ) {
                    if ( Database.instance.db.exists(dependency) ) {
                        queueMapDownload( Database.instance.db[dependency] );
                    } else {
                        trace( 'error; cannot find requirement with ID:$dependency -- this is a problem in the XML, please tell Quaddicted to fix this!');
                    }
                }
            }
            // download actual mod btw
            downloadThreadPool.run( () -> { downloadMapAsync(mapData.id, mapData.md5sum); } );
        } else {
            var mapID = mapData.id;
            trace( 'map $mapID was already downloaded, so not downloading it again');
        }
    }

    /** returns true if .zip file is in the downloads folder **/
    public function isMapDownloaded(mapID:String):Bool {
        var fullPath = getFullPath(Main.DOWNLOAD_PATH + "/" + mapID + ".zip");
        return FileSystem.exists(fullPath);
    }

    function downloadMapAsync(mapID:String, expectedMd5:String) {
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
            Main.mainThread.events.run( () -> { onDownloadMapSuccess(mapID); } );
        }
        http.onError = function(status) { 
            Main.mainThread.events.run( () -> { onDownloadMapError(mapID, status); } );
        }
        http.request();
    }

    public function onDownloadMapSuccess(mapID:String) {
        Notify.instance.addNotify(mapID, "finished downloading " + Database.instance.db[mapID].title);

        // TODO: thread this in background?
        // installModAsync( Database.instance.db[mapID] );
    }

    public function onDownloadMapError(mapID:String, error:String) {
        Notify.instance.addNotify(mapID, 'network error $error downloading ' + Database.instance.db[mapID].title );
    }

    public static function getModInstallFolder(mapData:MapEntry) {
        // we repackage all quakey mods with "quakey_" prefix to avoid breaking Quake installations or anything
        // the process for deciding what folder to put the mapData in:
        // 1. TODO: manual user override for where to put it
        // 2. try to use getModInstallFolderSuffix()
        return UserState.instance.currentData.quakePath + "/quakey_" + getModInstallFolderSuffix(mapData);
    }

    public static function getModInstallFolderSuffix(mapData:MapEntry) {
        // process for generating a mod folder suffix
        // 1. look for any "-game" command line ... this is good for most modern Quake packages (what most people will play)
        // 2. then check the zipbasedir .. this is good for most old map packs (1000+ items) that all use "id1/maps/"
        // 3. TODO: if both of those fail, then do this the hard way -- scan the .zip and look for root folder of any .dat or .pak or .bsp
        // 4. if all above fail, use the mapData.id

        // this process must be deterministic and reliable
        // the original idea was to just install everything in its own folder?
        // but we have to do this complicated process because some Quaddicted packages can go together
        // even though they're not always marked-up as "requirements" in the XML
        // and the only way you know they go together is if they just happen to share the same root mod folder

        
        var installSuffix = mapData.id; // default to the Quaddicted map ID
        var zipBaseDir = "";
        var foundGoodSuffix = false;
        // trace('getModInstallFolderSuffix for $installSuffix ...');

        if ( mapData.techinfo != null ) {
            // first, look for a "-game" commandline, e.g. "-game copper" but also possibly like "-hipnotic -game actualModName"
            if (mapData.techinfo.commandline != null && mapData.techinfo.commandline.contains("-game")) {
                var cmdLineClean = mapData.techinfo.commandline.trim();
                trace('getModInstallFolderSuffix scanning for gamedir in $cmdLineClean ...');
                while ( cmdLineClean.contains("  ") ) { // take no chances with extra whitespace
                    cmdLineClean.replace("  ", " ");
                }
                var cmdLineParts = cmdLineClean.split(" ");
                for ( i in 0...cmdLineParts.length) {
                    if (cmdLineParts[i].contains("-game") && cmdLineParts.length > i+1 && cmdLineParts[i+1].trim().length > 0) {
                        installSuffix = cmdLineParts[i+1].trim();
                        foundGoodSuffix = true;
                        break;
                    }
                }
            }
            // second, look for a zipbasedir ... e.g. "id1/maps/" or "/id1/maps" or "id1/" or "copper" etc.
            else if (mapData.techinfo.zipbasedir != null && mapData.techinfo.zipbasedir.replace("/", "").trim().length > 0) {
                var zipClean = mapData.techinfo.zipbasedir.trim();
                trace('getModInstallFolderSuffix scanning for gamedir in $zipClean ...');
                zipClean = zipClean.replace(" ", "").replace("\\", "/"); // take no chances with white space or slashes
                while ( zipClean.startsWith("/") ) {
                    zipClean = zipClean.substr(1); // no slash at the beginning
                }
                var zipCleanParts = zipClean.split("/");
                for( part in zipCleanParts ) {
                    if ( part != "maps" && part.length > 0 ) {
                        installSuffix = part;
                        foundGoodSuffix = true;
                        break;
                    }
                }
            }
            else if ( mapData.techinfo.commandline != null && mapData.techinfo.commandline.contains("-nehahra") ) {
                installSuffix = "nehahra";
                foundGoodSuffix = true;
            }
            else if ( mapData.techinfo.commandline != null && mapData.techinfo.commandline.contains("-quoth") ) {
                installSuffix = "quoth";
                foundGoodSuffix = true;
            }
            else if ( mapData.techinfo.commandline != null && mapData.techinfo.commandline.contains("-hipnotic") ) {
                installSuffix = "hipnotic";
                foundGoodSuffix = true;
            }
        }

        // TODO: try the hard way, and scan the .zip ... e.g. gsh_tod, soeskins_glquake
        if ( !foundGoodSuffix ) {

        }

        trace('getModInstallFolderSuffix for ' + mapData.id + ' is $installSuffix ... foundGoodSuffix: $foundGoodSuffix');
        return installSuffix;
    }

    public function installModAsync(mapData:MapEntry) {
        // if no template folder found, need to help user troubleshoot and set TEMPLATE_PATH?
        if ( !FileSystem.exists(getFullPath(Main.TEMPLATE_PATH) )) {
            Notify.instance.addNotify( mapData.id, "no Quake folder template was found at " + getFullPath(Main.TEMPLATE_PATH) + " so can't install " + mapData.title);
            return;
        }

        var newInstallFolder = getModInstallFolder(mapData);

        if ( !FileSystem.exists(newInstallFolder))
            FileSystem.createDirectory( newInstallFolder );
        var newMapsFolder = newInstallFolder + "/maps";
        if ( !FileSystem.exists(newMapsFolder))
            FileSystem.createDirectory( newMapsFolder );

        var unzipRoot = newInstallFolder;

        var zipBaseDir = mapData.techinfo != null ? mapData.techinfo.zipbasedir : null;
        if ( zipBaseDir != null && zipBaseDir.contains("maps") ) {
            unzipRoot = newMapsFolder;
        }

        // copy over template files
        var templateDir = Dir.of( getFullPath(Main.TEMPLATE_PATH));
        templateDir.copyTo(newInstallFolder, [DirCopyOption.OVERWRITE, DirCopyOption.MERGE]);
        trace("successfully copied base template files over to " + newInstallFolder);

        // unzip everything
        // TODO: unzip all dependencies first?
        unzip( getFullPath(Main.DOWNLOAD_PATH + "/" + mapData.id + ".zip"), unzipRoot );
        trace("successfully unzipped " + mapData.id + " to " + unzipRoot );

        // TODO: repackage phase: move all mod subfolders up one level
        
    }

    public static function unzip(unzipFilePath:String, localUnzipPath:String) {
        var zipfileBytes = File.getBytes(unzipFilePath);
        var bytesInput = new BytesInput(zipfileBytes);
        var reader = new Reader(bytesInput);
        var entries:List<Entry> = reader.read();
        for (_entry in entries) {
            var data = Reader.unzip(_entry);
            if (_entry.fileName.substring(_entry.fileName.lastIndexOf('/') + 1) == '' && _entry.data.toString() == '') {
                sys.FileSystem.createDirectory(localUnzipPath + _entry.fileName);
            } else {
                var f = File.write(localUnzipPath + _entry.fileName, true);
                f.write(data);
                f.close();
            }
        }
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