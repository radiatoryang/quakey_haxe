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

        Downloader.instance.getImageAsync(mapData.id + "_injector.jpg", onImageLoadedPreview );
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
        Database.refreshAllStates();
        disposeProfile(this);
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
        trace("openMapProfile: " + mapData.id);
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
        Main.moveToFrontButBeneathNotifications(mapProfile);
        mapProfile.show();

        // temp for testing
        // Notify.instance.addNotify(mapData.id, "opened " + mapData.title);
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