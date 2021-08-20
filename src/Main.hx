package ;

import haxe.ui.core.Screen;
import sys.thread.ElasticThreadPool;

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

    static var embedLoader:Loader;

    public static var BASE_DIR = "base_dir"; // has a trailing slash
    public static inline var CACHE_PATH = "cache";
    public static inline var DOWNLOAD_PATH = "download";
    // public static inline var INSTALLS_PATH = "installs";
    public static inline var TEMPLATE_PATH = "template";

    public static function main() {
        BASE_DIR = Sys.programPath();
        BASE_DIR = BASE_DIR.substring(0, BASE_DIR.length-("Main.hl").length );

        if (!FileSystem.exists(BASE_DIR + CACHE_PATH))
            FileSystem.createDirectory(BASE_DIR + CACHE_PATH);

        if (!FileSystem.exists(BASE_DIR + DOWNLOAD_PATH))
            FileSystem.createDirectory(BASE_DIR + DOWNLOAD_PATH);

        Res.initEmbed();
        embedLoader = hxd.Res.loader;

        mainThread = Thread.current();
        Downloader.init();

        // temp until the user select screen goes up
        if ( UserState.getUsers() != null ) {
            UserState.instance.currentData = UserState.loadUser( UserState.getUsers()[0] );
            Downloader.instance.queueAllMapDownloads( UserState.instance.currentData.mapQueue );
        }

        app = new HaxeUIApp();
        app.ready(function() {
            Toolkit.theme = "dark";
            TextDisplayImpl.channel = SDFChannel.Alpha;
            TextDisplayImpl.alphaCutoff = 0.5;
            TextDisplayImpl.smoothing = 0.05;

            mainView = new MainView();
            app.addComponent(mainView);
            app.start();

            app.addComponent( Notify.init() );

            // hxd.Window.getInstance().displayMode = DisplayMode.FullscreenResize;
        });
    }


}
