package ;

import haxe.ui.containers.Absolute;
import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.core.Component;
import haxe.Timer;
import haxe.ui.components.Button;
import haxe.ui.components.Label;
import haxe.ui.containers.VBox;
import haxe.io.Path;
import sys.Http;
import haxe.ui.macros.ComponentMacros;
import haxe.ui.core.Screen;

import sys.thread.Thread;
import hxd.res.Loader;
import hxd.Res;
import sys.FileSystem;
import sys.io.File;
import h2d.Font.SDFChannel;
import haxe.ui.backend.TextDisplayImpl;
import haxe.ui.Toolkit;
import haxe.ui.HaxeUIApp;

using StringTools;

class Main {

    static var db:Database;
    static var app:HaxeUIApp;
    public static var mainView:MainView;
    public static var mainThread:Thread;

    public static var online:Bool = false;
    public static var startupDone:Bool = false;

    static var embedLoader:Loader;
    public static var container:Absolute;
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

    public static var oldTrace: (Dynamic, Null<haxe.PosInfos>) -> Void;
    public static inline var LOG_PATH = "QuakeyLog.log";
    public static var logOutput: sys.io.FileOutput;

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

        // override Haxe's Logging so we can write logs to a file
        File.saveContent( BASE_DIR + LOG_PATH, "// QuakeyLog.log");
        oldTrace = haxe.Log.trace;
        haxe.Log.trace = Log; 


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

            // create a container component that we will parent everything to, since there's a sorting bug with just adding everything directly to screen root
            container = ComponentMacros.buildComponent("assets/container.xml");
            app.addComponent(container);

            // display splash screen while we load stuff
            splashScreen = ComponentMacros.buildComponent("assets/start-splash.xml");
            container.addComponent(splashScreen);

            app.start();

            // try to download data from Quaddicted, which WILL BLOCK execution! but that's ok at startup
            startConnectionTest();

            // hxd.Window.getInstance().displayMode = DisplayMode.FullscreenResize;
            hxd.Window.getInstance().onClose = confirmExit;
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
        container.addComponent( configScreen );

        // if config is nonexistent or bad
        if ( Config.instance.lastGoodConfig == null || !Config.validateConfig(Config.instance.lastGoodConfig) ) {
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
        if ( UserState.getUsers() != null && UserState.getUsers().length > 0 ) {
            UserState.instance.currentData = UserState.loadUser( UserState.getUsers()[0] );
        }

        mainView = new MainView();
        container.addComponent(mainView);

        app.addComponent( Overlay.init() );
        // app.addComponent( Notify.init() ); // temporarily disable half-finished Notifications system
        Downloader.init();
        Downloader.instance.queueAllMapDownloads( UserState.instance.currentData.mapQueue );

        container.addComponent( Search.init() );
        Search.instance.moveComponentToBack();
        Search.instance.hide();

        splashScreen.moveComponentToBack();
        splashScreen.hide();
        @:privateAccess splashScreen.destroyComponent(); 
        @:privateAccess splashScreen.dispose();

        MainView.instance.showMainView();
    }

    public static function showTopMostLayerAndMoveThisToBack(moveThisToBack:Component) {
        moveThisToBack.moveComponentToBack();
        moveThisToBack.hide();
        trace(container.childComponents.join(", "));
        var i = container.childComponents.length-1;
        while ( i >= 0 ) {
            if ( container.childComponents[i] == Overlay.instance ) {
                Overlay.instance.show();
                // Overlay.instance.validateNow();
            } else {
                container.childComponents[i].show();
                // container.childComponents[i].validateNow();
                break;
            }
            i--;
        }
    }

    public static function moveToFront(frontComponent:Component) {
        for( component in container.childComponents ) {
            if ( component != frontComponent )
                component.hide();
        }
        frontComponent.moveComponentToFront();
        // frontComponent.show();
        // frontComponent.validateNow();
    }

    public static function moveToFrontButBeneathNotifications(frontComponent:Component) {
        for( component in container.childComponents ) {
            component.hide();
        }
        frontComponent.moveComponentToFront();
        frontComponent.show();
        // frontComponent.validateNow();
        Overlay.instance.moveComponentToFront();
        Overlay.instance.show();
        // Overlay.instance.validateNow();

        // Screen.instance.setComponentIndex(frontComponent, Screen.instance.rootComponents.length - 2 );
        // Screen.instance.setComponentIndex(Overlay.instance, Screen.instance.rootComponents.length - 1 );

        // if ( Screen.instance.rootComponents[Screen.instance.rootComponents.length-1] == Overlay.instance ) {
        //     Screen.instance.setComponentIndex(frontComponent, Screen.instance.rootComponents.length - 2 );
        // } else {
        //     Screen.instance.setComponentIndex(frontComponent, Screen.instance.rootComponents.length - 1 );
        // }
    }

    public static function confirmExit() {
        if ( Downloader.instance != null && Downloader.instance.getCurrentMapDownloadProgress() >= 0 ) {
            var newDialog = new Dialog();
            newDialog.closable = false;
            newDialog.draggable = false;
            newDialog.buttons = haxe.ui.containers.dialogs.Dialog.DialogButton.CANCEL | haxe.ui.containers.dialogs.Dialog.DialogButton.OK;
            newDialog.width = 500;
            newDialog.dialogTitleLabel.text = "Download in progress! Quit?";
            newDialog.onDialogClosed = function(e:haxe.ui.containers.dialogs.Dialog.DialogEvent) {
                if ( e.button == haxe.ui.containers.dialogs.Dialog.DialogButton.OK ) {
                    hxd.System.exit();
                } 
            };
            newDialog.showDialog();
            return false;
        } else {
            return true;
        }
    }

    public static function Log(v:Dynamic, ?infos:haxe.PosInfos) {
        oldTrace(v, infos);
        if ( logOutput == null )
            logOutput = File.append( BASE_DIR + LOG_PATH, false );

        logOutput.writeString("\n[" + Date.now().toString() + "]  " + Std.string(v));
        logOutput.flush();
        logOutput.flush(); // I don't know why we flush twice (lol) but I saw another logging repo do it
    }


}
