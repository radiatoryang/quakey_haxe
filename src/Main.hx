package ;

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
    public static var BASE_DIR = "base_dir"; // has a trailing slash

    public static function main() {
        BASE_DIR = Sys.programPath();
        BASE_DIR = BASE_DIR.substring(0, BASE_DIR.length-("Main.hl").length );
        Res.initEmbed();
        embedLoader = hxd.Res.loader;
        localLoader = new hxd.res.Loader( new hxd.fs.LocalFileSystem(Main.BASE_DIR, "") );

        mainThread = Thread.current();
        threadPool = new ElasticThreadPool(1, 5.0); // need to keep this ThreadPool at 1 otherwise the CPU usage gets really intense

        // temp until the user select screen goes up
        UserState.instance = new UserState();

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
            // hxd.Window.getInstance().vsync = true;

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
                if ( count > 4) {
                    break;
                }
            }

            var newReleases = mainView.findComponent("newReleases", MapList);
            var latest = Lambda.array(db.db);
            latest.sort( (a,b) -> getTotalDays(b.date) - getTotalDays(a.date) );
            for( i in 0...8 ) {
                newReleases.addMapButton( latest[i] );
            }

            var highlyRated = mainView.findComponent("highlyRated", MapList);
            var highlyRatedOld = mainView.findComponent("highlyRatedOld", MapList);
            var rated = Lambda.array(db.db);

            var ratedModern = rated.filter( map -> map.rating >= 4.0 && map.date.getFullYear() >= 2010 );
            hxd.Rand.create().shuffle(ratedModern);
            for( i in 0... 8) {
                highlyRated.addMapButton( ratedModern[i] );
            }

            var ratedClassic = rated.filter( map -> map.rating >= 4.0 && map.date.getFullYear() < 2010 );
            hxd.Rand.create().shuffle(ratedClassic);
            for( i in 0... 8) {
                highlyRatedOld.addMapButton( ratedClassic[i] );
            }

            
        });
    }

    static inline function getTotalDays(date:Date) {
        return date.getFullYear() * 365 + date.getMonth() * 31 + date.getDate();
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
            http.onError = function(status) { 
                // TODO: queue another request later on?
                trace("error: " + status); 
            }
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
