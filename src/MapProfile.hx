package ;

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
            textFilter = new Glow(0x000000, 0.4, 1);

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
        var month = Database.getMonthName( mapData.date.getMonth() );
        date.text = mapData.date != null ? mapData.date.format(' %d $month %Y') : " ";
        if ( mapData.size != null && mapData.size > 0) {
            date.text += "    " + Std.string(mapData.size) + "mb";
        }
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

        var description = findComponent("description", Label);
        description.text = mapData.description;
        description.filter = textFilter;

        Downloader.instance.getImageAsync(mapData.id + "_injector.jpg", onImageLoadedPreview );
        Downloader.instance.getImageAsync(mapData.id + ".jpg", onImageLoaded );
    }

     /** mainly for refreshing the buttons on the map profile page; nothing else really changes **/
    public function refresh() {
        buttonQueue.text = switch( Database.instance.getMapStatus( mapData.id) ) {
            case NotQueued: "QUEUE DOWNLOAD";
            case Queued: "DOWNLOADING...";
            case Downloaded: "INSTALL AND PLAY";
        }
    }

    public static function refreshAllVisible() {
        for (mapProfile in cache) {
            if ( mapProfile.visible ) {
                mapProfile.refresh();
            }
        }
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
        refreshAllVisible();
    }

    @:bind(buttonQueue, MouseEvent.CLICK)
    private function onQueueButton(e:MouseEvent) {
        var status = Database.instance.getMapStatus( mapData.id);
        if ( status == MapStatus.NotQueued ) {
            Notify.instance.addNotify(mapData.id, "queued " + mapData.title + " for download");
            UserState.instance.queueMap( mapData.id );
            MainView.instance.refreshQueue();
        } else if ( status == MapStatus.Downloaded ) {
            // TODO: install and launch map?
        } else { 
            // do nothing, map is already queued and downloading
            // TODO... make it prioritize the download?
        }
        refresh();
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
            mapProfile.percentWidth = 100;
            mapProfile.percentHeight = 100;
            mapProfile.includeInLayout = false;
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
        mapProfile.refresh();

        // temp for testing
        // Notify.instance.addNotify(mapData.id, "opened " + mapData.title);
    }
}