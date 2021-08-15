package ;

import sys.io.File;

using StringTools;
using UnicodeString;

class Database {

    var xmlData:Xml;
    public var db: Map<String, MapEntry> = new Map<String, MapEntry>();

    public function new() {
        trace("beginning to read file...");
        xmlData = Xml.parse( File.getContent( "quaddicted_database.xml" ) );
        var root = xmlData.firstElement();
        for (file in root.elementsNamed("file")) {
            var id = file.get("id");
            var titleText = id;
            var authors = new Array<String>();
            var description = id;
            var date:Date = null;
            
            for(titleString in file.elementsNamed("title")) {
                titleText = titleString.firstChild().nodeValue.trim();
                if ( titleText == "Title" || titleText == "Untitled" ) {
                    titleText = id;
                }
            }

            for(authorString in file.elementsNamed("author")) {
                authors = authorString.firstChild().nodeValue.split(",");
                for(i in 0...authors.length) {
                    authors[i] = authors[i].trim();
                }
            }

            for (descString in file.elementsNamed("description")) {
                description = descString.firstChild().nodeValue.trim().replace("<br>", "\n").replace("<br />", "\n");
            }

            for (dateString in file.elementsNamed("date")) {
                var dateData = dateString.firstChild().nodeValue.trim();
                date = Date.fromString(dateData.substr(6, 4) + "-" + dateData.substr(3, 2) + "-" + dateData.substr(0, 2));
            }

            db.set( id, {id: id, title: titleText, authors: authors, description: description} );
        }
    }
}

typedef MapEntry = {
    var id:String;
    var title:String;
    
    var ?date:Date;
    var ?description:String;
    var ?rating:Float;
    var ?authors:Array<String>;
}