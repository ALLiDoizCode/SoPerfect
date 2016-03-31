import PerfectLib
//public method that is being called by the server framework to initialise your module.
public func PerfectServerModuleInit() {
    
    // Install the built-in routing handler.
    // Using this system is optional and you could install your own system if desired.
    Routing.Handler.registerGlobally()
    
    // Create Routes
    Routing.Routes["GET", ["/", "index.html"] ] = { (_:WebResponse) in return IndexHandler() }
    
    // Check the console to see the logical structure of what was installed.
    print("\(Routing.Routes.description)")
}

//Create a handler for index Route
class IndexHandler: RequestHandler {
    
    func handleRequest(request: WebRequest, response: WebResponse) {
        response.appendBodyString("Hello World")
        response.requestCompletedCallback()
    }
}

