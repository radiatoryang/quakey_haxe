package ;

import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.containers.dialogs.MessageBox;
import hx.concurrent.executor.Executor.TaskFutureBase;
import Database.MapState;
import datetime.utils.DateTimeMonthUtils;
import haxe.ui.core.Screen;
import Database.MapEntry;
import Database.MapStatus;

import hxd.System;
import h2d.filter.Filter;
import h2d.filter.Glow;
import h2d.filter.Blur;

import haxe.ui.containers.ScrollView;
import haxe.ui.components.Button;
import haxe.ui.containers.HBox;
import haxe.ui.components.Label;
import haxe.ui.containers.VBox;
import haxe.ui.events.MouseEvent;

import datetime.DateTime;

using StringTools;

@:build(haxe.ui.ComponentBuilder.build("assets/map-profile.xml"))
class MapProfile extends VBox {

    public var mapData:MapEntry;
    public static var cache:Map<String, MapProfile> = new Map<String, MapProfile>();
    static var textFilter:Filter;
    static var blurFilter:Filter;

    public function new() {
        super();
        
        if ( textFilter == null)
            textFilter = new Glow(0x000000, 0.69, 1);

        if ( blurFilter == null)
            blurFilter = new Blur(16.0);
    }

    public override function onInitialize() {
        super.onInitialize();

        findComponent("buttonQuad", Button).tooltip = "https://www.quaddicted.com/reviews/" + mapData.id + ".html";

        var componentTitle = findComponent("title", Label);
        componentTitle.text = mapData.title;
        componentTitle.tooltip = "map ID: " + mapData.id;
        componentTitle.filter = textFilter;

        var authorContainer = findComponent("authors", HBox);
        for(author in mapData.authors) {
            var newButton = new Button();
            newButton.text = author;
            newButton.tooltip = "search for more by " + author;
            newButton.onClick = function(e) { Search.instance.showSearch(author, Search.TextFilter.Author); };
            authorContainer.addComponent(newButton);
        }

        //var date = findComponent("date", Label);
        if (mapData.date != null) {
            var month = Database.getMonthName( mapData.date.getMonth() );
            date.text = mapData.date.format(' %d $month %Y');
            date.tooltip = Database.getRelativeTime(mapData.date);
        } else {
            date.text = "(undated)";
            date.tooltip = null;
        }
        date.filter = textFilter;

        // DISPLAY FILE SIZE
        sizeLabel.text = "";
        if ( mapData.size != null && mapData.size > 0) {
            sizeLabel.text = Std.string(mapData.size) + "mb";
        }
        if ( mapData.techinfo != null && mapData.techinfo.requirements != null && mapData.techinfo.requirements.length > 0 ) {
            var dependencySize = 0.0;
            var tooltip = "dependencies: "; // BUG: don't modify Label.tooltip in place, must assign it at the end
            for( dependency in mapData.techinfo.requirements ) {
                if ( Database.instance.db[dependency] != null && Database.instance.db[dependency].size != null ) {
                    var dep = Database.instance.db[dependency];
                    dependencySize += dep.size;
                    tooltip += "\n(+ " + dep.size + "mb) " + dep.title;
                } else {
                    trace('dependency ID $dependency was invalid! someone tell Quaddicted');
                    tooltip += "\n(" + dependency + ") INVALID ID! Please tell Quaddicted about this error!";
                }
            }
            sizeLabel.text += " (+ " + Std.string(dependencySize) + "mb)";
            sizeLabel.tooltip = tooltip;
        }
        sizeLabel.filter = textFilter;

        // DISPLAY RATING
        if ( mapData.rating != null && mapData.rating > 0) {
            ratingLabel.text = Std.string( mapData.ratingPercent ) + "%";
            if ( mapData.rating >= 4.6 ) {
                ratingLabel.text += " (GOD MODE!)";
            } else if ( mapData.rating >= 4.3 ) {
                ratingLabel.text += " (Highly recommended!)";
            } else if ( mapData.rating >= 4.0) {
                ratingLabel.text += " (Recommended!)";
            } else if ( mapData.rating >= 3.5) {
                ratingLabel.text += " (Great)";
            } else if ( mapData.rating >= 3.0) {
                ratingLabel.text += " (Good)";
            } else if ( mapData.rating >= 2.5) {
                ratingLabel.text += " (Average)";
            } else if ( mapData.rating >= 2.0) {
                ratingLabel.text += " (Below Average)";
            } else {
                ratingLabel.text += " (Not Recommended)";
            }
            ratingLabel.tooltip = "raw normalized user score: " + mapData.rating;
        } else {
            ratingLabel.text = "(unrated)";
        }
        ratingLabel.filter = textFilter;

        // TAGS
        var tagsContainer = findComponent("tags", HBox);
        if ( mapData.tags != null && mapData.tags.length > 0) {
            for(tag in mapData.tags) {
                var newButton = new Button();
                newButton.text = tag;
                newButton.tooltip = "search for all tagged with " + tag;
                newButton.onClick = function(e) { Search.instance.showSearch(tag, Search.TextFilter.Tags); };
                tagsContainer.addComponent(newButton);
            }
        } else {
            tagsContainer.hide();
        }

        var description = findComponent("description", Label);
        description.text = mapData.description;
        description.filter = textFilter;

        if ( mapData.links != null ) {
            for(link in mapData.links) {
                if ( Database.instance.db.exists(link) ) {
                    var linkData = Database.instance.db[link];
                    var newButton = new Button();
                    newButton.text = linkData.title;
                    newButton.tooltip = "click to view linked item " + link + "\n" + linkData.title;
                    newButton.onClick = function(e) { openMapProfile(linkData); };
                    description.parentComponent.addComponent(newButton);
                }
            }
        }

        Downloader.instance.getImageAsync(mapData.id + Downloader.thumbnailSuffix, onImageLoadedPreview );
        Downloader.instance.getImageAsync(mapData.id + ".jpg", onImageLoaded );

        Database.instance.subscribeToState(mapData.id, onRefresh);
    }

    public override function show() {
        super.show();
        forceRefresh();
        MainView.moveBelowMenuBar(this);
    }

    function forceRefresh() {
        onRefresh( Database.instance.getState(mapData.id) );
    }

     /** mainly for refreshing the buttons on the map profile page; nothing else really changes **/
    public function onRefresh(mapState:MapState) {
        // trace("MapProfile.onRefresh for " + mapData.id);
        switch( mapState.status ) {
            case NotQueued: 
                buttonLaunchOptions.show();
                buttonQueue.text = "QUEUE";
                buttonQueue.disabled = false;
                toggleFileButtons(false);
            case Queued: 
                buttonLaunchOptions.hide();
                buttonQueue.text = "QUEUED...";
                buttonQueue.disabled = true;
                toggleFileButtons(false);
            case Downloading: 
                buttonLaunchOptions.hide();
                buttonQueue.text = "DOWNLOADING " + Std.string(Math.round(mapState.downloadProgress*100)) + "%";
                buttonQueue.disabled = true;
                toggleFileButtons(false);
            case Downloaded: 
                buttonLaunchOptions.show();
                buttonQueue.text = "INSTALL";
                buttonQueue.disabled = false;
                toggleFileButtons(true);
            case Installing: 
                buttonLaunchOptions.hide();
                buttonQueue.text = "INSTALLING...";
                buttonQueue.disabled = true;
                toggleFileButtons(false);
            case Installed: 
                buttonLaunchOptions.show();
                buttonQueue.text =  "PLAY";
                buttonQueue.disabled = false;
                toggleFileButtons(true);
        }
        refreshQueueButtonTooltip(true);
        if (UserState.instance.currentData.mapActivity.exists(mapData.id)) {
            activity.show();
            var activ = UserState.instance.currentData.mapActivity[mapData.id];
            activity.text = "last " + Std.string(activ.activity).toLowerCase() + ": " + Database.getRelativeTime( DateTime.fromString(activ.timestamp) );
        } else {
            activity.hide();
        }
    }

    inline function toggleFileButtons(state:Bool) {
        menuManage.hidden = !state;
        // buttonDelete.hidden = buttonRedownload.hidden = buttonBrowse.hidden = !state;
    }

    public function onImageLoadedPreview(filepath:String) {
        filepath = Downloader.instance.allocateAndCacheImage(filepath);

        if ( filepath != null ) {
            findComponent("background-preview", VBox).backgroundImage = filepath;
            findComponent("background-preview", VBox).filter = blurFilter;
        }
    }

    public function onImageLoaded(filepath:String) {
        filepath = Downloader.instance.allocateAndCacheImage(filepath);

        if ( filepath != null )
            findComponent("background", ScrollView).backgroundImage = filepath;
    }
    
    @:bind(backButton, MouseEvent.CLICK)
    private function onBackButton(e:MouseEvent) {
        Database.refreshAllStates();
        Main.showTopMostLayerAndMoveThisToBack(this);
        disposeProfile(this);
    }

    @:bind(buttonQueue, MouseEvent.CLICK)
    private function onQueueButton(e:MouseEvent) {
        switch( Database.instance.getState(mapData.id, false).status ) {
            case NotQueued: 
                UserState.instance.queueMap( mapData.id );
            case Downloaded:
                Downloader.instance.queueMapInstall(mapData, true);
            case Installed: 
                UserState.instance.moveMapToFrontOfQueue( mapData.id );
                Launcher.launch(mapData);
            default:
                // do nothing
        }

        Database.instance.refreshState(mapData.id);
    }

    @:bind(buttonQueue, MouseEvent.MOUSE_OVER)
    private function onHoverQueueButton(e:MouseEvent) {
        refreshQueueButtonTooltip(true);
    }

    private function refreshQueueButtonTooltip(refresh:Bool=false) {
        switch( Database.instance.getState(mapData.id, refresh).status ) {
            case NotQueued: 
                buttonQueue.tooltip = "click to add this to your queue\nand Quakey will download and install it";
            case Queued:
                buttonQueue.tooltip = "Quakey is currently busy but it will\ndownload and install this soon";
            case Downloading:
                buttonQueue.tooltip = "Quakey is currently downloading this\nincluding any linked dependencies";
            case Downloaded:
                buttonQueue.tooltip = "click to install downloaded files";
            case Installing:
                buttonQueue.tooltip = "Quakey is currently installing this\nincluding any linked dependencies";
            case Installed: 
                buttonQueue.tooltip = "click to play with launch parameters\n" + Launcher.getActualLaunchArguments(mapData).replace(" -", "\n-").replace(" +", "\n+");
        }
    }

    @:bind(buttonLaunchOptions, MouseEvent.CLICK)
    private function onOptionsButton(e:MouseEvent) {
        switch( Database.instance.getState(mapData.id, false).status ) {
            case Installed:
                openLaunchDialog();
            case NotQueued:
                openInstallFolderDialog();
            case Downloaded:
                openInstallFolderDialog();
            default:
                // do nothing
        }
    }

    private function openLaunchDialog() {
        var launchDialog = new TextDialog();
        launchDialog.width = 1000;
        launchDialog.title = "Override launch parameters";
        launchDialog.defaultValue = Launcher.getDefaultLaunchArguments(mapData);
        launchDialog.onDialogClosed = function(e:haxe.ui.containers.dialogs.Dialog.DialogEvent) {
            if ( e.button == haxe.ui.containers.dialogs.Dialog.DialogButton.SAVE ) {
                var dialogValue = launchDialog.getDialogValue();
                if ( dialogValue != null && dialogValue.length > 0) {
                    // commit new override settings and queue install
                    // single quote vs double quote matters a lot for -basedir launch parameters, but breaks JSON, so it's... complicated
                    if ( dialogValue.replace("'", "\"") == Launcher.getDefaultLaunchArguments(mapData) ) {
                        UserState.instance.clearOverrideLaunch(mapData.id);
                    } else {
                        UserState.instance.setOverrideLaunch(mapData.id, dialogValue);
                    }
                } else {
                    UserState.instance.clearOverrideLaunch(mapData.id);
                }
            }
        };
        launchDialog.rename.text = Launcher.getActualLaunchArguments(mapData).replace("'", "\"");
        launchDialog.showDialog();
    }

    @:bind(buttonDelete, MouseEvent.CLICK)
    private function onDeleteButton(e:MouseEvent) {
        var newDialog = new Dialog();
        newDialog.closable = false;
        newDialog.draggable = false;
        newDialog.buttons = haxe.ui.containers.dialogs.Dialog.DialogButton.CANCEL | haxe.ui.containers.dialogs.Dialog.DialogButton.OK;
        newDialog.width = 500;
        newDialog.dialogTitleLabel.text = "Quakey will delete everything in " + Downloader.getModInstallFolder(mapData) + " including save data, screenshots, etc. ARE YOU SURE?";
        newDialog.onDialogClosed = function(e:haxe.ui.containers.dialogs.Dialog.DialogEvent) {
            if ( e.button == haxe.ui.containers.dialogs.Dialog.DialogButton.OK ) {
                doDelete();
            } 
        };
        newDialog.showDialog();
    }

    function doDelete() {
        UserState.instance.dequeueMap( mapData.id );
        Downloader.instance.tryDeleteAll( mapData.id );
        forceRefresh();
    }

    @:bind(buttonRedownload, MouseEvent.CLICK)
    private function onRedownloadButton(e:MouseEvent) {
        var newDialog = new Dialog();
        newDialog.closable = false;
        newDialog.draggable = false;
        newDialog.buttons = haxe.ui.containers.dialogs.Dialog.DialogButton.CANCEL | haxe.ui.containers.dialogs.Dialog.DialogButton.OK;
        newDialog.width = 500;
        newDialog.dialogTitleLabel.text = "To reinstall everything cleanly and ensure compatibility, Quakey will delete everything in " + Downloader.getModInstallFolder(mapData) + " including save data, screenshots, etc. ARE YOU SURE?";
        newDialog.onDialogClosed = function(e:haxe.ui.containers.dialogs.Dialog.DialogEvent) {
            if ( e.button == haxe.ui.containers.dialogs.Dialog.DialogButton.OK ) {
                doRedownload();
            } 
        };
        newDialog.showDialog();
    }

    function doRedownload() {
        Downloader.instance.tryDeleteAll( mapData.id );
        Downloader.instance.queueMapDownload(mapData);
        forceRefresh();
    }

    @:bind(buttonReinstall, MouseEvent.CLICK)
    private function onReinstallButton(e:MouseEvent) {
        openInstallFolderDialog();
    }

    private function openInstallFolderDialog() {
        var changeFolderDialog = new TextDialog();
        changeFolderDialog.title = "Install this mod with folder name...";
        changeFolderDialog.defaultValue = Downloader.getModInstallFolderNameDefault(mapData);
        changeFolderDialog.onDialogClosed = function(e:haxe.ui.containers.dialogs.Dialog.DialogEvent) {
            if ( e.button == haxe.ui.containers.dialogs.Dialog.DialogButton.SAVE ) {
                var dialogValue = changeFolderDialog.getDialogValue();
                if ( dialogValue != null && dialogValue.length > 0) {
                    // delete old install, if it used the default folder name (safe to delete?)
                    // if ( Downloader.isModInstalled(mapData.id) && Downloader.getModInstallFolderName(mapData) == Downloader.getModInstallFolderNameDefault(mapData) ) {
                    //     Downloader.instance.tryDeleteInstall(mapData.id);
                    // }
                    // commit new override settings and queue install
                    if ( dialogValue == Downloader.getModInstallFolderNameDefault(mapData) ) {
                        UserState.instance.clearOverrideInstall(mapData.id);
                    } else {
                        UserState.instance.setOverrideInstall(mapData.id, dialogValue);
                    }
                    Downloader.instance.queueMapInstall(mapData, true, true);
                } else {
                    UserState.instance.clearOverrideInstall(mapData.id);
                }
            }
        };
        changeFolderDialog.rename.text = Downloader.getModInstallFolderName(mapData);
        changeFolderDialog.showDialog();
    }

    @:bind(buttonBrowse, MouseEvent.CLICK)
    private function onBrowseButton(e:MouseEvent) {
        Launcher.openInExplorer( Downloader.getModInstallFolder(mapData) );
    }

    @:bind(buttonMark, MouseEvent.CLICK)
    private function onMarkButton(e:MouseEvent) {
        UserState.instance.markMap( mapData.id );
        onBackButton(e);
    }

    @:bind(buttonQuad, MouseEvent.CLICK)
    private function onQuadButton(e:MouseEvent) {
        System.openURL("https://www.quaddicted.com/reviews/" + mapData.id + ".html");
    }

    public static function openMapProfile(mapData:MapEntry) {
        trace("openMapProfile: " + mapData.id);
        if ( MapProfile.cache.exists(mapData.id)==false ) {
            var mapProfile = new MapProfile();
            // mapProfile.percentWidth = 100;
            // mapProfile.percentHeight = 100;
            // mapProfile.includeInLayout = false;
            mapProfile.mapData = mapData;
            Main.container.addComponent(mapProfile);
            MapProfile.cache.set(mapData.id, mapProfile);
        }
        var mapProfile = MapProfile.cache[mapData.id];
        Main.moveToFrontButBeneathNotifications(mapProfile);
        mapProfile.show();

        // temp for testing
        Notify.notify(mapData.id, "opened " + mapData.title);
    }

    public static function clearProfileCache() {
        for( profile in cache) {
            disposeProfile(profile);
        }
    }

    public static function disposeProfile(profile:MapProfile) {
        profile.hide();
        if ( MapProfile.cache.exists(profile.mapData.id) ) {
            MapProfile.cache.remove(profile.mapData.id);
        }
        Downloader.instance.disposeImage(profile.mapData.id + ".jpg");
        profile.destroyComponent();
        profile.dispose();
    }
}