package ;

import sys.thread.Mutex;
import sys.thread.ElasticThreadPool;
import haxe.ui.backend.heaps.TileCache;
import sys.thread.Thread;
import haxe.ui.ToolkitAssets;
import hxd.res.Loader;
import haxe.ui.components.Image;
import hxd.Res;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Bytes;
import haxe.ui.containers.HBox;
import hxd.Window.DisplayMode;
import h2d.Font.SDFChannel;
import haxe.ui.core.TextDisplay;
import haxe.ui.backend.TextDisplayImpl;
import haxe.ui.Toolkit;
import haxe.ui.HaxeUIApp;

using StringTools;

class Main {

    static var db:Database;
    public static var app:HaxeUIApp;
    public static var mainView:MainView;

    public static var mainThread:Thread;
    static var threadPool: ElasticThreadPool;

    static var embedLoader:Loader;
    static var localLoader:Loader;

    public static inline var CACHE_PATH = "cache";
    public static var BASE_DIR = "base_dir";

    public static function main() {
        BASE_DIR = Sys.programPath();
        BASE_DIR = BASE_DIR.substring(0, BASE_DIR.length-("Main.hl").length );
        Res.initEmbed();
        embedLoader = hxd.Res.loader;
        localLoader = new hxd.res.Loader( new hxd.fs.LocalFileSystem(Main.BASE_DIR, "") );

        mainThread = Thread.current();
        threadPool = new ElasticThreadPool(4);

        app = new HaxeUIApp();
        app.ready(function() {
            Toolkit.theme = "dark";
            TextDisplayImpl.channel = SDFChannel.Alpha;
            TextDisplayImpl.alphaCutoff = 0.5;
            TextDisplayImpl.smoothing = 0.05;

            mainView = new MainView();
            app.addComponent(mainView);
            app.start();

            // hxd.Window.getInstance().displayMode = DisplayMode.FullscreenResize;
            hxd.Window.getInstance().title = "Quakey";

            db = new Database();

            var queue = mainView.findComponent("queue", MapList);
            var count = 0;
            if (!FileSystem.exists(BASE_DIR + CACHE_PATH))
            {
                FileSystem.createDirectory(BASE_DIR + CACHE_PATH);
            }
            for( mapData in db.db ) {
                queue.addMapButton(mapData);
                count++;
                if ( count > 15) {
                    break;
                }
            }
        });
    }

    public static function getImageAsync(filename:String, callback:String->Void) {
        threadPool.run( () -> { downloadImage(filename, callback); } );
    }

    public static function downloadImage(filename:String, callback:String -> Void) {
        var localPath = CACHE_PATH + "/" + filename;
        var fullPath = BASE_DIR + localPath;
        var fullPathWindows = BASE_DIR + localPath.replace("/", "\\");
        if ( !FileSystem.exists(fullPathWindows) ) {
            var url = "https://www.quaddicted.com/reviews/screenshots/" + filename;
            var http = new haxe.Http(url);
            http.onBytes = function(bytes) { 
                File.saveBytes(fullPathWindows, bytes); 
                mainThread.events.run( () -> { callback(localPath); } );
            }
            http.onError = function(status) { trace("error: " + status); }
            http.request();
        } else {
            // callback( localPath );
            mainThread.events.run( () -> { callback(localPath); } );
        }
    }

    /* returns filepath string if the image filepath is valid */
    public static function allocateAndCacheImage(filepath:String) {
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

        // hxd.Res.loader = localLoader;
        // ToolkitAssets.instance.getImage(filepath, null); 
        // hxd.Res.loader = embedLoader;

        return filepath;
    }

    static function cacheImage(filepath:String, image:hxd.res.Image) {
        var imageData = { width: image.getSize().width, height: image.getSize().height, data: image.toBitmap() };
        @:privateAccess ToolkitAssets.instance._imageCache.set(filepath, imageData);
        TileCache.set(filepath, image.toTile() );
    }
}
