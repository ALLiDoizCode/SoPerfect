import PerfectLib
import MySQL
//public method that is being called by the server framework to initialise your module.

// host where mysql server is
let HOST = "mysql://bc44c07f739aab:18b62184@us-cdbr-iron-east-03.cleardb.net/heroku_a51e4868e5ceaa4?reconnect=true"
// mysql username
let USER = "bc44c07f739aab"
// mysql root password
let PASSWORD = "18b62184" // make your password something MUCH safer!!!
// database name
let SCHEMA = "RandomPosts"
// table name
let POST_TABLE = "Post"

public func PerfectServerModuleInit() {
    
    // initialize mysql
    let mysql = MySQL()
    let connected = mysql.connect(HOST, user: USER, password: PASSWORD)
    guard connected else {
        // verify we connected successfully
        print(mysql.errorMessage())
        return
    }
    
    // defering close ensure the connection is close when we're done here.
    defer {
        mysql.close()
    }
    
    // create DB schema if needed
    var schemaExists = mysql.selectDatabase(SCHEMA)
    if !schemaExists {
        schemaExists = mysql.query("CREATE SCHEMA \(SCHEMA) DEFAULT CHARACTER SET utf8mb4;")
    }
    
    let tableSuccess = mysql.query("CREATE TABLE IF NOT EXISTS \(POST_TABLE) (id INT(11) AUTO_INCREMENT, Content varchar(255), PRIMARY KEY (id))")
    
    guard schemaExists && tableSuccess else {
        print(mysql.errorMessage())
        return
    }

    
    // Install the built-in routing handler.
    // Using this system is optional and you could install your own system if desired.
    Routing.Handler.registerGlobally()
    
    // register a route for gettings posts
    Routing.Routes["GET", "/posts"] = { _ in
        return GetPostHandler()
    }
    
    // register a route for creating a new post
    Routing.Routes["POST", "/posts"] = { _ in
        return PostHandler()
    }
}

class GetPostsHandler: RequestHandler {
    func handleRequest(request: WebRequest, response: WebResponse) {
        
        // open mysql connection
        let mysql = MySQL()
        let connected = mysql.connect(HOST, user: USER, password: PASSWORD)
        guard connected else {
            print(mysql.errorMessage())
            response.setStatus(500, message: "Server Error")
            response.requestCompletedCallback()
            return
        }
        
        // select the db we're using
        mysql.selectDatabase(SCHEMA)
        defer {
            mysql.close()
        }
        
        // run our select query
        let querySuccess = mysql.query("SELECT Content FROM \(POST_TABLE) ORDER BY RAND() LIMIT 1")
        // make sure the query worked
        guard querySuccess else {
            print(mysql.errorMessage())
            response.setStatus(500, message: "Server Error")
            response.requestCompletedCallback()
            return
        }
        
        // now fetch the results
        let results = mysql.storeResults()!
        // we check for one row because we had the LIMIT 1 in our query
        guard results.numRows() == 1 else {
            print("no rows found")
            response.setStatus(500, message: "Server Error")
            response.requestCompletedCallback()
            return
        }
        
        results.forEachRow { row in
            // each row is a of type MySQL.MySQL.Results.Type.Element
            // which is just a typealias for [String]
            print("fetched: \(row)")
            let content = row[0] // element 0 will be Content because it was the first (and only) colum in our query
            
            do {
                // encode the random content into JSON
                let jsonEncoder = JSONEncoder()
                let respString = try jsonEncoder.encode(["content": content])
                
                // write the JSON to the response body
                response.appendBodyString(respString)
                response.addHeader("Content-Type", value: "application/json")
                response.setStatus(200, message: "OK")
            } catch {
                response.setStatus(500, message: "Server Error")
            }
            
        }
        
        response.requestCompletedCallback()
    }
}

class PostHandler: RequestHandler {
    func handleRequest(request: WebRequest, response: WebResponse) {
        let reqData = request.postBodyString    // get the request body
        let jsonDecoder = JSONDecoder() // JSON decoder
        do {
            // decode(_:) returns a JSONValue, which is just an alias to Any
            // because we know the request will be a dictionary, we can just force
            // the downcast to JSONDictionaryType. In a real production web service,
            // you would include error checking here to validate the request that it is what
            // we expect. For the purpose of this tutorial, we're gonna lean
            // on the side of danger
            let json = try jsonDecoder.decode(reqData) as! JSONDictionaryType
            print("received request JSON: \(json.dictionary)")
            
            let content = json.dictionary["content"] as? String    // again, error check is VERY important here
            
            guard content != nil else {
                // bad request, bail out
                response.setStatus(400, message: "Bad Request")
                response.requestCompletedCallback()
                return
            }
            
            // open mysql connection
            let mysql = MySQL()
            let connected = mysql.connect(HOST, user: USER, password: PASSWORD)
            guard connected else {
                print(mysql.errorMessage())
                response.setStatus(500, message: "Server Error")
                response.requestCompletedCallback()
                return
            }
            
            // select our db
            mysql.selectDatabase(SCHEMA)
            
            defer {
                mysql.close()
            }
            
            let querySuccess = mysql.query("INSERT INTO \(POST_TABLE) (Content) VALUES ('\(content!)')")
            guard querySuccess else {
                // query failed, report error
                print(mysql.errorMessage())
                response.setStatus(500, message: "Server Error")
                response.requestCompletedCallback()
                return
            }
            
            response.setStatus(201, message: "Created")
        } catch {
            print("error decoding json from data: \(reqData)")
            response.setStatus(400, message: "Bad Request")
        }
        
        // this completes the request and sends the response to the client
        response.requestCompletedCallback()
    }
}

