package ;


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

    public function new() {
        super();
        
        if ( textFilter == null)
            textFilter = new Glow(0x000000, 0.25, 1);
    }

    public override function onInitialize() {
        super.onInitialize();

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
        date.text = mapData.date != null ? mapData.date.format("%d %B %Y") : "";
        date.filter = textFilter;

        var description = findComponent("description", Label);
        description.text = mapData.description;
        description.filter = textFilter;

        Main.getImageAsync(mapData.id + "_injector.jpg", onImageLoadedPreview );
        Main.getImageAsync(mapData.id + ".jpg", onImageLoaded );
    }

    public function onImageLoadedPreview(filepath:String) {
        filepath = Main.allocateAndCacheImage(filepath);

        if ( filepath != null )
            findComponent("background-preview", VBox).backgroundImage = filepath;
    }

    public function onImageLoaded(filepath:String) {
        filepath = Main.allocateAndCacheImage(filepath);

        if ( filepath != null )
            findComponent("background", ScrollView).backgroundImage = filepath;
    }
    
    @:bind(backButton, MouseEvent.CLICK)
    private function onBackButton(e:MouseEvent) {
        hide();
        // TODO: actually delete it? or cache it?
    }
}