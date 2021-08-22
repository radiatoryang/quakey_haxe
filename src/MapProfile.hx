package ;

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
        componentTitle.filter = textFilter;

        var authorContainer = findComponent("authors", HBox);
        for(author in mapData.authors) {
            var newButton = new Button();
            newButton.text = author;
            authorContainer.addComponent(newButton);
        }

        var date = findComponent("date", Label);
        if (mapData.date != null) {
            var month = Database.getMonthName( mapData.date.getMonth() );
            date.text = mapData.date.format(' %d $month %Y');
        } else {
            date.text = "(undated)";
        }

        // DISPLAY FILE SIZE
        if ( mapData.size != null && mapData.size > 0) {
            date.text += "    " + Std.string(mapData.size) + "mb";
        }
        if ( mapData.techinfo != null && mapData.techinfo.requirements != null && mapData.techinfo.requirements.length > 0 ) {
            var dependencySize = 0.0;
            for( dependency in mapData.techinfo.requirements ) {
                dependencySize += Database.instance.db[dependency].size;
            }
            date.text += " (+ dependencies: " + Std.string(dependencySize) + "mb)";
        }

        // DISPLAY RATING
        if ( mapData.rating != null && mapData.rating > 0) {
            date.text += "    " + Std.string( Math.round(Math.sqrt(mapData.rating * 0.2) * 100) ) + "%";
            if ( mapData.rating >= 4.75 ) {
                date.text += " (GOD MODE!)";
            } else if ( mapData.rating >= 4.5 ) {
                date.text += " (Highly recommended!)";
            } else if ( mapData.rating >= 4.0) {
                date.text += " (Recommended!)";
            } else if ( mapData.rating >= 3.5) {
                date.text += " (Great)";
            } else if ( mapData.rating >= 3.0) {
                date.text += " (Good)";
            } else if ( mapData.rating >= 2.5) {
                date.text += " (Average)";
            } else if ( mapData.rating >= 2.0) {
                date.text += " (Below Average)";
            } else {
                date.text += " (Not Recommended)";
            }
        }
        date.filter = textFilter;
        date.tooltip = Database.getRelativeTime(mapData.date);

        var tagsContainer = findComponent("tags", HBox);
        if ( mapData.tags != null && mapData.tags.length > 0) {
            for(tag in mapData.tags) {
                var newButton = new Button();
                newButton.text = tag;
                tagsContainer.addComponent(newButton);
            }
        } else {
            tagsContainer.hide();
        }

        var description = findComponent("description", Label);
        description.text = mapData.description;
        description.filter = textFilter;

        Downloader.instance.getImageAsync(mapData.id + "_injector.jpg", onImageLoadedPreview );
        Downloader.instance.getImageAsync(mapData.id + ".jpg", onImageLoaded );

        Database.instance.subscribeToState(mapData.id, onRefresh);
    }

    public override function show() {
        super.show();
        forceRefresh();
    }

    function forceRefresh() {
        onRefresh( Database.instance.getState(mapData.id) );
    }

     /** mainly for refreshing the buttons on the map profile page; nothing else really changes **/
    public function onRefresh(mapState:MapState) {
        // trace("MapProfile.onRefresh for " + mapData.id);
        switch( mapState.status ) {
            case NotQueued: 
                buttonQueue.text = "QUEUE DOWNLOAD";
                buttonQueue.disabled = false;
                toggleFileButtons(false);
            case Queued: 
                buttonQueue.text = "QUEUED...";
                buttonQueue.disabled = true;
                toggleFileButtons(false);
            case Downloading: 
                buttonQueue.text = "DOWNLOADING " + Std.string(Math.round(mapState.downloadProgress*100)) + "%";
                buttonQueue.disabled = true;
                toggleFileButtons(false);
            case Downloaded: 
                buttonQueue.text = "INSTALLING...";
                buttonQueue.disabled = true;
                toggleFileButtons(true);
            case Installed: 
                buttonQueue.text =  "PLAY >";
                buttonQueue.disabled = false;
                toggleFileButtons(true);
        }
    }

    inline function toggleFileButtons(state:Bool) {
        buttonDelete.hidden = buttonRedownload.hidden = buttonBrowse.hidden = !state;
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
        hide();
        Database.refreshAllStates();
    }

    @:bind(buttonQueue, MouseEvent.CLICK)
    private function onQueueButton(e:MouseEvent) {
        switch( Database.instance.getState(mapData.id, false).status ) {
            case NotQueued: 
                UserState.instance.queueMap( mapData.id );
            case Installed: 
                UserState.instance.moveMapToFrontOfQueue( mapData.id );
                Launcher.launch(mapData);
            default:
                // do nothing
        }

        Database.instance.refreshState(mapData.id);
    }

    @:bind(buttonDelete, MouseEvent.CLICK)
    private function onDeleteButton(e:MouseEvent) {
        UserState.instance.dequeueMap( mapData.id );
        Downloader.instance.tryDeleteAll( mapData.id );

        forceRefresh();
    }

    @:bind(buttonRedownload, MouseEvent.CLICK)
    private function onRedownloadButton(e:MouseEvent) {
        Downloader.instance.tryDeleteAll( mapData.id );
        Downloader.instance.queueMapDownload(mapData);
        forceRefresh();
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
        if ( MapProfile.cache.exists(mapData.id)==false ) {
            var mapProfile = new MapProfile();
            // mapProfile.percentWidth = 100;
            // mapProfile.percentHeight = 100;
            // mapProfile.includeInLayout = false;
            mapProfile.mapData = mapData;
            Main.app.addComponent(mapProfile);
            MapProfile.cache.set(mapData.id, mapProfile);
        }
        var mapProfile = MapProfile.cache[mapData.id];
        // push new map profile screen to the front, but don't push it in front of the Notifications layer
        if ( Screen.instance.rootComponents[Screen.instance.rootComponents.length-1] == Notify.instance ) {
            Screen.instance.setComponentIndex(mapProfile, Screen.instance.rootComponents.length - 1 );
        } else {
            Screen.instance.setComponentIndex(mapProfile, Screen.instance.rootComponents.length );
        }
        mapProfile.show();

        // temp for testing
        // Notify.instance.addNotify(mapData.id, "opened " + mapData.title);
    }
}