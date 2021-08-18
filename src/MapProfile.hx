package ;


import h2d.filter.Blur;
import hxd.System;
import h2d.filter.Filter;
import h2d.filter.Glow;
import h2d.filter.DropShadow;
import haxe.ui.containers.ScrollView;
import haxe.ui.components.Button;
import haxe.ui.containers.HBox;
import haxe.ui.components.Label;
import Database.MapEntry;
import haxe.ui.containers.VBox;
import haxe.ui.events.MouseEvent;

using DateTools;

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
        date.text = mapData.date != null ? mapData.date.format(" %d %B %Y") : " ";
        if ( mapData.size != null && mapData.size > 0) {
            date.text += "    " + Std.string(mapData.size) + "mb";
        }
        if ( mapData.rating != null && mapData.rating > 0) {
            date.text += "    " + Std.string(mapData.rating * 20) + "%";
            if ( mapData.rating > 4.75 ) {
                date.text += " (GOD MODE)";
            } else if ( mapData.rating > 4.5 ) {
                date.text += " (Highly recommended!)";
            } else if ( mapData.rating > 4.0) {
                date.text += " (Great)";
            } else if ( mapData.rating > 3.5) {
                date.text += " (Very Good)";
            } else if ( mapData.rating > 3.0) {
                date.text += " (Good)";
            } else if ( mapData.rating > 2.5) {
                date.text += " (Average)";
            } else {
                date.text += " (Terrible)";
            }
        }
        date.filter = textFilter;

        var description = findComponent("description", Label);
        description.text = mapData.description;
        description.filter = textFilter;

        Main.getImageAsync(mapData.id + "_injector.jpg", onImageLoadedPreview );
        Main.getImageAsync(mapData.id + ".jpg", onImageLoaded );
    }

    public function onImageLoadedPreview(filepath:String) {
        filepath = Main.allocateAndCacheImage(filepath);

        if ( filepath != null ) {
            findComponent("background-preview", VBox).backgroundImage = filepath;
            findComponent("background-preview", VBox).filter = blurFilter;
        }
    }

    public function onImageLoaded(filepath:String) {
        filepath = Main.allocateAndCacheImage(filepath);

        if ( filepath != null )
            findComponent("background", ScrollView).backgroundImage = filepath;
    }


    
    @:bind(backButton, MouseEvent.CLICK)
    private function onBackButton(e:MouseEvent) {
        hide();
    }

    @:bind(buttonQueue, MouseEvent.CLICK)
    private function onQueueButton(e:MouseEvent) {
        UserState.instance.queueMap( mapData.id );
        MainView.instance.refreshQueue();
        // TODO: update map profile screen?
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
}