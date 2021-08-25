package ;

import haxe.Timer;
import haxe.ui.components.Button;
import haxe.ui.components.Label;
import haxe.ui.containers.VBox;
import haxe.io.Path;
import sys.Http;
import haxe.ui.macros.ComponentMacros;
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

    public static var online:Bool = false;
    public static var startupDone:Bool = false;

    static var embedLoader:Loader;
    static var splashScreen:VBox;
    static var delayConnectionTest:Timer;
    static var configScreen:VBox;

    public static inline var PROGRAM_NAME = "Quakey";
    public static var BASE_DIR = "base_dir"; // has a trailing slash
    public static inline var CACHE_PATH = "cache";
    public static inline var DOWNLOAD_PATH = "download";
    public static inline var ENGINE_PATH = "engines"; // default engines path
    public static inline var ENGINE_QUAKESPASM_PATH = "engines/quakespasm-spiked/";
    public static inline var INSTALL_PATH = "mods"; // default mod install path
    public static var PROGRAM_DIR = "program_dir";
    public static inline var TEMPLATE_PATH = "template";

    static inline var databaseURL = "https://www.quaddicted.com/reviews/quaddicted_database.xml";

    public static inline var FORCE_PROGRAM_PATH = false;
    public static inline var USE_OLD_DATABASE = true;
    public static inline var FORCE_OFFLINE = false;

    public static function main() {
        // first, try to figure out where to put all the files
        PROGRAM_DIR = Sys.programPath(); 
        PROGRAM_DIR = PROGRAM_DIR.substring(0, PROGRAM_DIR.length-("Main.hl").length );

        var appData = Sys.getEnv("APPDATA"); // default to Windows AppData, like a good samaritan
        if ( !FORCE_PROGRAM_PATH && appData != null && appData.length > 0 && FileSystem.exists(Path.addTrailingSlash(appData)) ) {
            BASE_DIR = Path.addTrailingSlash( Path.normalize( Path.addTrailingSlash(appData) + PROGRAM_NAME) );
        } else {
            BASE_DIR = PROGRAM_DIR; // if we can't use AppData, then just dump everything in the local path (portable mode?)
        }

        if (!FileSystem.exists(BASE_DIR) )
            FileSystem.createDirectory(BASE_DIR);

        if (!FileSystem.exists(BASE_DIR + CACHE_PATH))
            FileSystem.createDirectory(BASE_DIR + CACHE_PATH);

        if (!FileSystem.exists(BASE_DIR + DOWNLOAD_PATH))
            FileSystem.createDirectory(BASE_DIR + DOWNLOAD_PATH);

        if (!FileSystem.exists(BASE_DIR + INSTALL_PATH))
            FileSystem.createDirectory(BASE_DIR + INSTALL_PATH);

        Res.initEmbed();
        embedLoader = hxd.Res.loader;
        mainThread = Thread.current();

        app = new HaxeUIApp();
        app.ready(function() {
            Toolkit.theme = "dark";
            TextDisplayImpl.channel = SDFChannel.Alpha;
            TextDisplayImpl.alphaCutoff = 0.5;
            TextDisplayImpl.smoothing = 0.05;

            // display splash screen while we load stuff
            splashScreen = ComponentMacros.buildComponent("assets/start-splash.xml");
            app.addComponent(splashScreen);
            app.start();

            // try to download data from Quaddicted, which WILL BLOCK execution! but that's ok at startup
            startConnectionTest();

            // hxd.Window.getInstance().displayMode = DisplayMode.FullscreenResize;
            hxd.Window.getInstance().onClose = onExit;
        });
    }

    public static function startConnectionTest() {
        splashScreen.findComponent("offline", VBox).hide();

        if ( USE_OLD_DATABASE || FORCE_OFFLINE ) {
            if ( FORCE_OFFLINE )
                online = false; 
            continueStartup();
        } else {
            delayConnectionTest = new Timer(1000);
            delayConnectionTest.run = connectionTest;
        }
    }

    public static function connectionTest() {
        delayConnectionTest.stop();

        var https = new Http(databaseURL);
        https.cnxTimeout = 30;
        https.onStatus = connectStatus;
        https.onError = connectFailed;
        https.onData = connectSuccess;
        https.request();
    }

    static function connectStatus(errorCode:Int) {
        if ( errorCode >= 204 ) {
            connectFailed("HTTP STATUS CODE: " + Std.string(errorCode) );
        }
    }

    static function connectFailed(error:String) {
        var errorString = "ERROR: couldn't connect to " + databaseURL + "\nREASON: " + error;
        trace(errorString);
        splashScreen.findComponent("offline", VBox).show();
        splashScreen.findComponent("error", Label).text = errorString;
        splashScreen.findComponent("buttonRetry", Button).onClick = function(e) { startConnectionTest(); }
        splashScreen.findComponent("buttonOffline", Button).onClick = function(e) { online = false; continueStartup(); }
    }

    static function connectSuccess(data:String) {
        trace("XML database successfully downloaded from "+ databaseURL);
        File.saveContent(Main.BASE_DIR + Path.addTrailingSlash(Main.CACHE_PATH) + "quaddicted_database.xml", data);
        online = true;
        continueStartup();
    }

    public static function continueStartup() {
        trace("continuing startup...");

        // initialize config
        configScreen = Config.init();
        app.addComponent( configScreen );

        // if config is nonexistent or bad
        if ( Config.instance.currentConfig == null || !Config.validateConfig(Config.instance.currentConfig) ) {
            configScreen.show();
            return;
        } 
        configScreen.hide();

        continueStartupForRealNoSeriously();
    }

    public static function continueStartupForRealNoSeriously() {
        startupDone = true;
        Database.init();

        // temp until the user select screen goes up
        if ( UserState.getUsers() != null ) {
            UserState.instance.currentData = UserState.loadUser( UserState.getUsers()[0] );
        }

        mainView = new MainView();
        app.addComponent(mainView);

        app.addComponent( Notify.init() );
        Downloader.init();
        Downloader.instance.queueAllMapDownloads( UserState.instance.currentData.mapQueue );

        splashScreen.hide();
    }

    public static function onExit() {
        trace("exiting Quakey!");
        return true;
    }


}
