package ;

import sys.io.File;

using StringTools;
using UnicodeString;

class MapData {

    var xmlData:Xml;
    var db: Map<String, MapEntry> = new Map<String, MapEntry>();

    public function new() {
        trace("beginning to read file...");
        xmlData = Xml.parse( File.getContent( "quaddicted_database.xml" ) );
        var root = xmlData.firstElement();
        for (file in root.elementsNamed("file")) {
            for(title in file.elementsNamed("title")) {
                var id = file.get("id");
                var titleText = title.firstChild().nodeValue.trim();
                if ( titleText == "Title" || titleText == "Untitled" ) {
                    titleText = id;
                }
                trace( titleText + ": " + id );
                db.set( id, {id: id, title: titleText} );
            }
        }
    }
}

typedef MapEntry = {
    var id:String;
    var title:String;
    
    var ?date:String;
    var ?description:String;
    var ?rating:Float;
    var ?authors:Array<String>;
}