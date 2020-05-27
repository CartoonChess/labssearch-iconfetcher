//
//  IconFetcher.swift
//  LabsSearch
//
//  Created by Xcode on ’18/12/14.
//

import UIKit

/// Handles functions related to finding the most suitable icon image file at a remote server.
///
/// This is a class, and conforms to NSObject, in order to use parsing functions.
class IconFetcher: NSObject, XMLParserDelegate {
    
    // MARK: - Parameters
    
    /// This will be set when passed in to `fetchIcon()`.
    var url: URL?
    /// This will first receive objects from the XML parser, then be added to by `findIconsInHtml()`.
    var icons = [HtmlIcon]()
    
    /// If `IconFetcher` successfully retrieves HTML, it will be saved so that a `SearchEngineEditor` object can reuse it.
    var html: String?
    // We can just borrow this from SearchEngineEditor in the future hopefully, possibly through delegation
    var characterEncoder: CharacterEncoder?
    
    
    // MARK: -
    
    /// Checks that the user- or host app-supplied URL is formatted correctly for retrieving an icon.
    ///
    /// - Parameter urlString: The URL as a string.
    /// - Returns: A tupple of `URL` and the host string if successful, otherwise `nil`.
    func getUrlComponents(_ urlString: String, characterEncoder encoder: CharacterEncoder? = nil) -> (URL, String)? {
        // Convert urlString into URL components
        guard let encodedUrl = urlString.encodedUrl(characterEncoder: encoder),
            var components = URLComponents(url: encodedUrl, resolvingAgainstBaseURL: true) else {
            print("Failed to convert URL text field contents to URL for background retrieval.")
            return nil
        }
        
        // Must be a webpage (not e.g. sms://) for this to work; also, must use https
        if components.scheme == "http" {
            components.scheme = "https"
        } else if components.scheme != "https" {
            // If the URL wasn't http(s), don't try to load it in the background
            print("Cannot load URL in background for non-http(s) URLs.")
            return nil
        }
        
        guard let url = components.url,
            let host = components.host else {
                print("Failed to synthesize URL components into functional URL.")
                return nil
        }
        
        return (url, host)
    }
    
    
    // MARK: - Fetching methods
    
    
    /// Creates an image file from the image retrieved from a remote server.
    ///
    /// - Parameters:
    ///   - url: The URL as entered by the user. This will be sent to the class so that the parser has access to it as well.
    ///   - completion: Passes the image file after all network calls have been completed.
    ///   - icon: The image retrieved from the Internet.
    ///
    /// This is the only method which should be called from a view controller.
    ///
    /// The inner workings of this function and those related to it perform asynchronously on the background thread. If updating the UI with the image this function fetches, be sure to update on the main thread.
    func fetchIcon(for url: URL, completion: @escaping (_ icon: UIImage?) -> Void) {
        // Give URL to class so parser can access it
        self.url = url
        // Clear out icons in case this isn't the first time we're checking
        icons.removeAll()
        // Cancel any previous scrape if running
        URLSession.shared.invalidateAndCancel()
        
        checkPossibleIconUrls { (bestIcon) in
            if let data = bestIcon.data,
                let icon = UIImage(data: data) {
                print("Creating icon from HtmlIcon data (URL \(bestIcon.href)).")
                completion(icon)
            } else {
                // Return nil so that we can still update encoding
                completion(nil)
            }
        }
    }


    /// Checks a remote server for various likely icon files, retrieves those which exist, and compares all of them, plus any icons parsed from the URL's HTML in findIconsInHtml(), to select the most suitable icon.
    ///
    /// - Parameters:
    ///   - completion: Passes the most suitable icon once all icons have been downloaded and compared against one another.
    ///   - bestIcon: The `HtmlIcon` with the most desirable traits.
    private func checkPossibleIconUrls(completion: @escaping (_ bestIcon: HtmlIcon) -> Void) {
        guard let url = url,
            let host = url.host else {
            print("URL invalid, or does not have a valid host.")
            return
        }
        
        findIconsInHtml(at: url) {
            // After parsing the HTML, look in the root directory of the site as well
            // Must use httpS for iOS security purposes
            let rootUrl = "https://\(host)/"
            
            let possibleIcons = [
                "apple-touch-icon-180x180-precomposed.png",
                "apple-touch-icon-180x180.png",
                "apple-touch-icon-152x152-precomposed.png",
                "apple-touch-icon-152x152.png",
                "apple-touch-icon-144x144-precomposed.png",
                "apple-touch-icon-144x144.png",
                "apple-touch-icon-120x120-precomposed.png",
                "apple-touch-icon-120x120.png",
                "apple-touch-icon-114x114-precomposed.png",
                "apple-touch-icon-114x114.png",
                "apple-touch-icon-76x76-precomposed.png",
                "apple-touch-icon-76x76.png",
                "apple-touch-icon-72x72-precomposed.png",
                "apple-touch-icon-72x72.png",
                "apple-touch-icon-60x60-precomposed.png",
                "apple-touch-icon-60x60.png",
                "apple-touch-icon-57x57-precomposed.png",
                "apple-touch-icon-57x57.png",
                "apple-touch-icon-precomposed.png",
                "apple-touch-icon.png",
                
                "touch-icon-192x192.png",
                "touch-icon.png",
                
                "favicon-256x256.png",
                "favicon-256x256.ico",
                "favicon-96x96.png",
                "favicon-96x96.ico",
                "favicon-48x48.png",
                "favicon-48x48.ico",
                "favicon-32x32.png",
                "favicon-32x32.ico",
                "favicon-16x16.png",
                "favicon-16x16.ico",
                "favicon.png",
                "favicon.ico",
                
                "msapplication-square558x558logo.png",
                "msapplication-square310x310logo.png",
                "msapplication-square270x270logo.png",
                "msapplication-square150x150logo.png",
                "msapplication-square128x128logo.png",
                "msapplication-square70x70logo.png",
                
                "mstile-310x310.png",
                "mstile-270x270.png",
                "mstile-144x144.png",
                "mstile-70x70.png"
            ]
            
            // Add possible icons to array of icons found in parsed HTML
            for filename in possibleIcons {
                let url = "\(rootUrl)\(filename)"
                // Get size, if available
                let size = Int(filename.components(separatedBy: "x")[0].components(separatedBy: "-").last ?? "0") ?? 0
                
                // Note that we use the full URL in place of any rel attribute here
                let icon = HtmlIcon(href: url, rel: url, size: size, data: nil)
                
                // Add it to the icons array along with the parsed ones
                // TODO: We could try to check if this is duplicating any of the parsed hrefs
                self.icons.append(icon)
            }
            
            // This will be replaced by an icon any time it's determined to be better than the previous best option
            var bestIcon = HtmlIcon(href: "", rel: "", size: 0, data: nil)
            
            // An asynchronous counter to know when we've seen every icon
            var checkedIcons = 0
            
            // Look for all icons
            for icon in self.icons {
                guard let url = URL(string: icon.href) else {
                    print("Possible icon URL was malformed, so we will not attempt to fetch from there.")
                    // TODO: Does this continue statement work as expected?
                    continue
                }
                
                let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
                    checkedIcons += 1
                    
                    // If server returns 200, test icon at URL against previous best
                    // TODO: Maybe we should use `!= 404` or something similar
                    if let data = data,
                        let response = response as? HTTPURLResponse,
                        response.statusCode == 200 {
                        print("Found icon \(checkedIcons) of \(self.icons.count) at URL \(icon.href).")
                        
                        // Add data to the icon
                        let icon = HtmlIcon(href: icon.href, rel: icon.rel, size: icon.size, data: data)
                        
                        // Preference: Exists, named apple-touch-icon*, largest size
                        
                        if bestIcon.href.isEmpty {
                            print("Setting new icon (bestIcon was empty).")
                            bestIcon = icon
                        } else if !bestIcon.rel.contains("apple-touch-icon") && icon.rel.contains("apple-touch-icon") {
                            print("Setting new icon (apple-touch-icon preferred).")
                            bestIcon = icon
                        } else if (
                            (bestIcon.rel.contains("apple-touch-icon") &&                               icon.rel.contains("apple-touch-icon")
                                ) || (!bestIcon.rel.contains("apple-touch-icon") && !icon.rel.contains("apple-touch-icon")
                            )
                            ) && bestIcon.size <= icon.size {
                            // If icons are both (not) apple and new icon is bigger
                            print("Old icon (size \(bestIcon.size)) replaced by new icon (size \(icon.size)).")
                            bestIcon = icon
                        }
                    }
                    
                    // When final URL is checked, move on to processing data for best candidate
                    if checkedIcons == self.icons.count {
                        completion(bestIcon)
                    }
                }
                task.resume()
            }
        }
    }


    /// Fetches the HTML of a given URL and calls the XML parses delegate to parse the <head> tag.
    ///
    /// - Parameters:
    ///   - url: The source of the HTML to parse.
    ///   - completion: An empty enclosure which is only run once the parsing has completed.
    private func findIconsInHtml(at url: URL, completion: @escaping () -> Void) {
        // Use standard Mobile Safari user agent
        var request = URLRequest(url: url)
        // TODO: We can create a phantom WKWebView, load an empty page, and use JavaScript in Swift to ask for the user-agent
        let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 12_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Mobile/15E148 Safari/604.1"
        request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        // Retrieve HTML in background
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            // Get the HTML character encoding so we can parse it properly
            let encodingName = response?.textEncodingName ?? "nil"
            self.characterEncoder = CharacterEncoder(encoding: encodingName)
            let encoding = self.characterEncoder?.encoding.value
            
            if let data = data {
                // Look for icon:
                
                //- Just get the <head> part, if it's defined
                // We'll try to use the page's character encoding if we can get it
                var html = String(data: data, encoding: encoding ?? .utf8)
                // Keep HTML for SearchEngineEditor
                self.html = html
                let components = html?.components(separatedBy: "<head")
                
                // If the split work, we've got a <head> tag, or possibly <header>
                if let components = components,
                    components.count > 1 {
                    
                    switch components[1].first {
                    case ">", " ":
                        // Head tag was found, so we're only using that part of the HTML
                        let head = components[1].components(separatedBy: "</head>")
                        html = "<head\(head[0])</head>)"
                    default:
                        // No head tag was found; we'll just use the full HTML
                        print("No head tag found; using full HTML source code.")
                        break
                    }
                }
                
                // Parse the HTML as XML; delegate is instructed to look for elements relevant to icons
                guard let xml = html?.data(using: .utf8) else {
                    print("Failed to convert HTML to XML.")
                    completion()
                    return
                }
                
                let parser = XMLParser(data: xml)
                // IconFetcher takes on parser delegate functions itself
                parser.delegate = self
                
                parser.parse()
                
                // Pass best icon to next function to compare it against root level icons
                completion()
            } else {
                if let error = error {
                    print("Failed to load URL in background with error: \(error)")
                } else {
                    print("Failed to load URL in background (no error reported by server).")
                }
//                 #if !EXTENSION
                DispatchQueue.main.async {                    
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
//                 #endif
            }
        }
        
        task.resume()
    }
    
    
    // MARK: - XML parsing functions
    
    
    // Parses each XML tag to look for <link> items with icon-related rels
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        // We're only concerned with <link> tags
        if elementName == "link" {
            // We only want those with icon rel attributes
            guard let rel = attributeDict["rel"],
                rel.hasPrefix("apple-touch-icon") || rel == "shortcut icon" || rel == "icon" else {
                    return
            }
            
            // Make sure this is an absolute URL using httpS
            guard let unformattedHref = attributeDict["href"],
                let absoluteUrl = URL(string: unformattedHref, relativeTo: url)?.absoluteString,
                var components = URLComponents(string: absoluteUrl) else {
                    print("Failed to format <link> href into absolute URL.")
                    return
            }
            components.scheme = "https"
            guard let href = components.string else {
                print("Failed to format <link> href into https URL.")
                return
            }
            
            // Set an int for the size (i.e. "144" instead of "144x144") if supplied, otherwise zero
            var size = 0
            
            if let sizes = attributeDict["sizes"] {
                let string = String(sizes)
                size = Int(string.components(separatedBy: "x")[0]) ?? 0
            }
            
            let icon = HtmlIcon(href: href, rel: rel, size: size, data: nil)
            
            // Add this new icon to the list of candidates
            icons.append(icon)
            print("Appended icon.")
        }
    }
    
    // Stop looking for icon info once we leave the <head> tag
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "head" {
            print("Aborting XML parsing because closing head tag was reached.")
            parser.abortParsing()
        }
    }

}
