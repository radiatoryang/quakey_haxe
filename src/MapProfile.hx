package ;


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

    public function new() {
        super();
    }

    public override function onInitialize() {
        super.onInitialize();
        findComponent("title", Label).text = mapData.title;
        var authorContainer = findComponent("authors", HBox);
        for(author in mapData.authors) {
            var newButton = new Button();
            newButton.text = author;
            authorContainer.addComponent(newButton);
        }
        findComponent("description", Label).text = mapData.description;
        findComponent("date", Label).text = mapData.date != null ? mapData.date.format("%d %B %Y") : "";
    }
    
    @:bind(backButton, MouseEvent.CLICK)
    private function onBackButton(e:MouseEvent) {
        hide();
        // TODO: actually delete it? or cache it?
    }
}