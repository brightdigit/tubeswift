//
//  OAuthClient.swift
//  TubeSwift
//
//  Created by Leo G Dion on 4/27/15.
//  Copyright (c) 2015 Leo G Dion. All rights reserved.
//

import UIKit

public enum TokenType {
	case Bearer
}

public enum OAuthAuthorization {
	static func  parseFrom(#webView: UIWebView) -> OAuthAuthorization?  {
		if let docTitleComponents = webView.stringByEvaluatingJavaScriptFromString("document.title")?.componentsSeparatedByString(" ") {
			let webViewResponse = docTitleComponents.map{$0.componentsSeparatedByString("=")}
			if let result = webViewResponse.first?.first {
				if result.caseInsensitiveCompare("Success") == NSComparisonResult.OrderedSame {
					if webViewResponse.last?.first?.caseInsensitiveCompare("code") == NSComparisonResult.OrderedSame {
						if let code = webViewResponse.last?.last {
							return OAuthAuthorization.Success(code: code)
						}
					}
				} else if result.caseInsensitiveCompare("Error") == NSComparisonResult.OrderedSame {
					if webViewResponse.last?.first?.caseInsensitiveCompare("error") == NSComparisonResult.OrderedSame {
						if let error = webViewResponse.last?.last {
							return OAuthAuthorization.Error(error: error)
						}
					}
				} else if result.caseInsensitiveCompare("Request") == NSComparisonResult.OrderedSame {
					return OAuthAuthorization.Request
				}
			}
		}
		return nil
	}
	//public let code:String
	case Success(code: String), Error(error: String), Request
}

public class OAuthWebViewController : UIViewController, UIWebViewDelegate {
	public weak var webView:UIWebView?
	public let completion:(UIViewController, OAuthAuthorization?, NSError?) -> Void
	public let url: NSURL
	
	public init (authorize_url: NSURL, completion: (UIViewController, OAuthAuthorization?, NSError?) -> Void) {

		self.url = authorize_url
		self.completion = completion
				super.init(nibName: nil, bundle: nil)
	}

	required public init(coder aDecoder: NSCoder) {

	    fatalError("init(coder:) has not been implemented")
	}
	
	public override func viewDidLoad() {
		let webView = UIWebView(frame: self.view.frame)
		self.view.addSubview(webView)
		self.webView = webView
		super.viewDidLoad()
		self.webView!.delegate = self
		self.webView!.loadRequest(NSURLRequest(URL: self.url))
	}
	
	public func webViewDidFinishLoad(webView: UIWebView) {
		if let authorization = OAuthAuthorization.parseFrom(webView: webView) {
			switch authorization {
			case .Request:
				return
			default:
				self.completion(self, authorization, nil)
			}
		} else {
			return
		}
		webView.delegate = nil
	}
}


public class OAuthClient: NSObject {
	public let client: TubeSwiftClient
	public init (client : TubeSwiftClient) {
		self.client = client
	}
	public func refreshToken (refresh_token: String, completion: (NSURLRequest, NSURLResponse?, OAuthToken?, NSError?) -> Void) {
		request(Method.POST, self.client.settings.token_uri, parameters: [
			"client_id":self.client.settings.client_id,
			"client_secret":self.client.settings.client_secret,
			"refresh_token": refresh_token,
			"grant_type":"refresh_token"
			]).responseJSON(options: .allZeros, completionHandler: { (request, response, result, error) -> Void in
				if let aError = error {
					completion(request, response, nil, aError)
				}
				else if let token = OAuthToken.parse(result, refresh_token: refresh_token) {
					self.client.token = token
					completion(request, response, token, nil)
				} else {
					completion(request, response, nil, NSError())
				}
		})
	}

	public func requestAuthorization (parentViewController: UIViewController, scopes : [Scope], completion: (UIViewController, OAuthAuthorization?, NSError?) -> Void) -> UIViewController? {
		
		if let url = self.client.settings.authorize_url(scopes) {
			let destinationViewController = OAuthWebViewController(authorize_url: url, completion: completion)
			parentViewController.presentViewController(destinationViewController, animated: true, completion: nil)
			return destinationViewController
		}
		
		return nil
	}
	
	public func requestToken (auth_code: String, completion: (NSURLRequest, NSURLResponse?, OAuthToken?, NSError?) -> Void) {
		request(.POST, self.client.settings.token_uri, parameters: [
			"code":auth_code,
			"client_id":self.client.settings.client_id,
			"client_secret":self.client.settings.client_secret,
			"redirect_uri":self.client.settings.redirect_uri,
			"grant_type":"authorization_code"]).responseJSON(options: NSJSONReadingOptions.allZeros, completionHandler: { (request, response, result, error) -> Void in
				if let aError = error {
					completion(request, response, nil, aError)
				}
				else if let token = OAuthToken.parse(result) {
					completion(request, response, token, nil)
				} else {
					completion(request, response, nil, NSError())
				}
			})
	}

}
