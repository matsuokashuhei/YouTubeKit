//
//  Client.swift
//  YouTubeKit
//
//  Created by matsuosh on 2015/02/26.
//  Copyright (c) 2015年 matsuosh. All rights reserved.
//

import Alamofire
import Result
import Box

class Client {

    static var sharedInstance = Client()

    var maxResults: Int = 25

    func suggestions(#keyword: String, handler: (Result<[String], NSError>) -> Void) {
        let request = Alamofire.request(API.Suggestions(keyword: keyword))
        //debugPrintln(request)
        request.responseJSON { (_, _, object, error) -> Void in
            if let error = error {
                handler(.Failure(Box(error)))
                return
            }
            if let JSON = object as? NSArray {
                var suggestions = [String]()
                if let keywords = JSON[1] as? NSArray {
                    for keyword in keywords {
                        if let keyword = keyword as? NSArray {
                            if let suggestion = keyword[0] as? String {
                                suggestions.append(suggestion)
                            }
                        }
                    }
                }
                handler(.Success(Box(suggestions)))
            } else {
                handler(.Failure(Box(ResponseError.Unknown.toNSError())))
            }
        }
    }

    func search<T: APIDelegate>(#parameters: [String: String], handler: (Result<(page: Page, items: [T]), NSError>) -> Void) {
        var _parameters = parameters
        _parameters["type"] = T.type
        _parameters["maxResults"] = "\(maxResults)"
        let request = Alamofire.request(API.Search(parameters: _parameters))
        //debugPrintln(request)
        request.responseJSON { (_, _, object, error) -> Void in
            switch self.validate(object) {
            case .Success(let box):
                let JSON = box.value
                let page = Page(JSON: JSON)
                if let items = JSON["items"] as? [NSDictionary] {
                    let ids: [String] = items.map { item -> String in
                        let id = item["id"] as! NSDictionary
                        return id["\(T.type)Id"] as! String
                    }
                    let parameters = ["id": ",".join(ids)]
                    self.find(parameters: parameters) { (response: Result<[T], NSError>) -> Void in
                        switch response {
                        case .Success(let box):
                            handler(.Success(Box((page: page, items: box.value))))
                        case .Failure(let box):
                            handler(.Failure(Box(box.value)))
                        }
                    }
                } else {
                    handler(.Success(Box((page: page, items: []))))
                }
            case .Failure(let box):
                handler(.Failure(Box(box.value)))
            }
        }
    }

    func find<T: APIDelegate>(#parameters: [String: String], handler: (Result<[T], NSError>) -> Void) {
        let request = Alamofire.request(T.callAPI(parameters))
        //debugPrintln(request)
        request.responseJSON { (_, _, object, error) -> Void in
            switch self.validate(object) {
            case .Success(let box):
                let JSON = box.value
                if let _items = JSON["items"] as? [NSDictionary] {
                    let items = _items.filter { (item) -> Bool in
                            if let item = T(JSON: item) {
                                return true
                            } else {
                                return false
                            }
                        }.map { (item) -> T in
                            return T(JSON: item)!
                        }
                    handler(.Success(Box(items)))
                } else {
                    // 結果が0の場合
                    handler(.Success(Box([T]())))
                }
            case .Failure(let box):
                handler(.Failure(Box(box.value)))
            }
        }
    }

    func plyalistItems(#parameters: [String: String], handler: (Result<(page: Page, items: [Video]), NSError>) -> Void) {
        var _parameters = parameters
        _parameters["maxResults"] = "\(maxResults)"
        let request = Alamofire.request(API.PlaylistItems(parameters: _parameters))
        //debugPrintln(request)
        request.responseJSON { (_, _, object, error) -> Void in
            switch self.validate(object) {
            case .Success(let box):
                let JSON = box.value
                let page = Page(JSON: JSON)
                if let items = JSON["items"] as? [NSDictionary] {
                    let ids: [String] = items.map { item -> String in
                        let contentDetails = item["contentDetails"] as! NSDictionary
                        return contentDetails["videoId"] as! String
                    }
                    let parameters = ["id": ",".join(ids)]
                    self.find(parameters: parameters) { (response: Result<[Video], NSError>) -> Void in
                        switch response {
                        case .Success(let box):
                            handler(.Success(Box((page: page, items: box.value))))
                        case .Failure(let box):
                            handler(.Failure(Box(box.value)))
                        }
                    }
                } else {
                    handler(.Success(Box((page: page, items: []))))
                }
            case .Failure(let box):
                handler(.Failure(Box(box.value)))
            }
        }

    }

    func guideCategories(handler: (Result<[GuideCategory], NSError>) -> Void) {
        let request = Alamofire.request(API.GuideCategories())
        //debugPrintln(request)
        request.responseJSON { (_, _, object, error) -> Void in
            switch self.validate(object) {
            case .Success(let box):
                let JSON = box.value
                if let items = JSON["items"] as? [NSDictionary] {
                    let categories = items.map { (item) -> GuideCategory in
                        return GuideCategory(JSON: item)
                    }
                    handler(.Success(Box(categories)))
                } else {
                    handler(.Failure(Box(ResponseError.Unknown.toNSError())))
                }
            case .Failure(let box):
                handler(.Failure(Box(box.value)))
            }
        }
    }

    func videos(#parameters: [String: String], handler: (Result<(page: Page, videos: [Video]), NSError>) -> Void) {
        var _parameters = parameters
        _parameters["maxResults"] = "\(maxResults)"
        let request = Alamofire.request(API.Videos(parameters: _parameters))
        //debugPrintln(request)
        request.responseJSON { (_, _, object, error) -> Void in
            switch self.validate(object) {
            case .Success(let box):
                let JSON = box.value
                let page = Page(JSON: JSON)
                if let items = JSON["items"] as? [NSDictionary] {
                    let videos = items.filter { (item) -> Bool in
                            if let video = Video(JSON: item) {
                                return true
                            }
                            return false
                        }.map { (item) -> Video in
                            return Video(JSON: item)!
                        }
                    handler(.Success(Box((page: page, videos: videos))))
                } else {
                    handler(.Failure(Box(ResponseError.Unknown.toNSError())))
                }
            case .Failure(let box):
                handler(.Failure(box))
            }
        }
    }

    func channels(#parameters: [String: String], handler: (Result<(page: Page, channels: [Channel]), NSError>) -> Void) {
        var _parameters = parameters
        _parameters["maxResults"] = "\(maxResults)"
        let request = Alamofire.request(API.Channels(parameters: _parameters))
        //debugPrintln(request)
        request.responseJSON { (_, _, object, error) -> Void in
            switch self.validate(object) {
            case .Success(let box):
                let JSON = box.value
                let page = Page(JSON: JSON)
                if let items = JSON["items"] as? [NSDictionary] {
                    let channels = items.filter { (item) -> Bool in
                            if let channel =  Channel(JSON: item) {
                                return true
                            }
                            return false
                        }.map { (item) -> Channel in
                            return Channel(JSON: item)!
                        }
                    handler(.Success(Box((page: page, channels: channels))))
                } else {
                    handler(.Failure(Box(ResponseError.Unknown.toNSError())))
                }
            case .Failure(let box):
                handler(.Failure(box))
            }
        }
    }

    private func validate(object: AnyObject?) -> Result<NSDictionary, NSError> {
        if let JSON = object as? NSDictionary {
            if let error = Error(JSON: JSON) {
                return .Failure(Box(error.toNSError()))
            }
            return .Success(Box(JSON))
        } else {
            return .Failure(Box(ResponseError.Unknown.toNSError()))
        }
    }
}