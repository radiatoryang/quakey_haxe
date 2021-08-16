package ;

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

class Main {

    static var db:Database;
    public static var app:HaxeUIApp;
    static var mainView:MainView;

    public static inline var CACHE_PATH = "cache";
    public static var BASE_DIR = "base_dir";

    public static function main() {
        BASE_DIR = Sys.programPath();
        BASE_DIR = BASE_DIR.substring(0, BASE_DIR.length-("Main.hl").length );
        Res.initEmbed();
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
                if ( count > 1) // hack
                    queue.addMapButton(mapData);
                count++;
                if ( count > 10) {
                    break;
                }
            }
        });
    }
}
