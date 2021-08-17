package ;

import sys.io.File;

using StringTools;
using UnicodeString;

class Database {

    var xmlData:Xml;
    public var db: Map<String, MapEntry> = new Map<String, MapEntry>();

    public function new() {
        var htmlStripRegex = ~/<[^>]*>/g;

        xmlData = Xml.parse( File.getContent( "quaddicted_database.xml" ) );
        var root = xmlData.firstElement();
        for (file in root.elementsNamed("file")) {
            var id = file.get("id");
            var titleText = id;
            var authors = new Array<String>();
            var description = id;
            var date:Date = null;
            var size = -1.0;
            var rating = Std.parseFloat(file.get("normalized_users_rating"));
            
            for(titleString in file.elementsNamed("title")) {
                titleText = titleString.firstChild().nodeValue.trim();
                if ( titleText == "Title" || titleText == "Untitled" ) {
                    titleText = id;
                }
            }

            for(authorString in file.elementsNamed("author")) {
                authors = authorString.firstChild().nodeValue.split(","); // TODO: split on "&" and "&amp;" too
                for(i in 0...authors.length) {
                    authors[i] = authors[i].trim();
                }
            }

            for (descString in file.elementsNamed("description")) {
                description = descString.firstChild().nodeValue.trim().replace("<br>", "\n").replace("<br/>", "\n").replace("<br />", "\n");
                description = htmlStripRegex.replace(description, "");
            }

            for (dateString in file.elementsNamed("date")) {
                var dateData = dateString.firstChild().nodeValue.trim().split(".");
                date = Date.fromString(dateData[2] + "-" + dateData[1] + "-" + dateData[0]);
            }

            for (sizeString in file.elementsNamed("size")) {
                size = Std.parseInt(sizeString.firstChild().nodeValue.trim()) / 1000.0;
            }

            db.set( id, {
                id: id, 
                title: titleText, 
                authors: authors, 
                description: description, 
                date: date, 
                size: size, 
                rating: rating
            } );
        }
    }
}

typedef MapEntry = {
    var id:String;
    var title:String;
    
    var ?size:Float;
    var ?date:Date;
    var ?description:String;
    var ?rating:Float;
    var ?authors:Array<String>;

    var ?techInfo:TechInfo;
}

typedef TechInfo = {
    var zipbasedir:String;
    var ?commandline:String;
    var ?startmap:Array<String>;
    var ?requirements:Array<String>;
}