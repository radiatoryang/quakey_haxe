package;

import Database.MapEntry;
import haxe.ui.ToolkitAssets;
import sys.FileSystem;
import sys.io.File;
import sys.thread.ElasticThreadPool;
import format.tools.MD5;
import format.zip.Reader;

import hxd.res.Loader;
import haxe.ui.backend.heaps.TileCache;

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
        // TODO: unzip and install
    }

    public function onDownloadMapError(mapID:String, error:String) {
        Notify.instance.addNotify(mapID, 'network error $error downloading ' + Database.instance.db[mapID].title );
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