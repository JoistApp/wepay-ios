//
//  WePay.m
//  WePay
//
//  Created by WePay on 10/2/13.
//  Copyright (c) 2013 WePay. All rights reserved.
//

#import "WPResource.h"

@interface WPResource()

// get api request url
+ (NSURL *) apiUrlWithEndpoint: (NSString *) endpoint;

// convert data from WePay to error object
+ (NSError *) errorFromResponse: (NSDictionary *) dictionary;

// Helper for makeRequestToEndPoint to process API call request response
+ (void) processResponse: (NSURLResponse *) response data: (NSData *) data error: (NSError *)error successBlock: (WPSuccessBlock) successHandler errorHandler: (WPErrorBlock) errorHandler;

@end

@implementation WPResource

// URL roots to make API calls.
// prod
static NSString * const prodApiUrlRoot = @"https://wepayapi.com/v2/";

// stage
static NSString * const stageApiUrlRoot = @"https://stage.wepayapi.com/v2/";

// Version number to be appended to URL root.
static NSString * const version = @"v2";


+ (NSURL *) apiUrlWithEndpoint: (NSString *) endpoint {
    
    [WePay validateCredentials];
    
    NSString * rootUrl;
    
    if ([WePay isProduction]) {
        rootUrl =  prodApiUrlRoot;
    }
    else {
        rootUrl = stageApiUrlRoot;
    }
    
    return [[NSURL URLWithString: [NSString stringWithFormat: @"%@", rootUrl]] URLByAppendingPathComponent: endpoint];
}


# pragma mark API Requests and Handling

/*
 Handle Wepay Error. Create NSError object with returned error code, category, and description.
 */
+ (NSError *) errorFromResponse: (NSDictionary *) dictionary {
    NSMutableDictionary * details = [NSMutableDictionary dictionary];
    
    NSInteger errorCode;
    NSString * errorText;
    NSString * errorCategory;
    
    if([dictionary objectForKey: @"error_code"] != (id)[NSNull null]) {
        errorCode = [[dictionary objectForKey: @"error_code"] intValue];
    }
    else {
        // This should not happen
        errorCode = WPErrorUnknown;
    }
    
    if([dictionary objectForKey: @"error_description"] != (id)[NSNull null] &&
       [[dictionary objectForKey: @"error_description"] length]) {
        errorText = [dictionary objectForKey: @"error_description"];
    }
    else if(dictionary == nil) {
        // This should not happen
        errorText = WPNoDataReturnedErrorMessage;
    }
    else {
        // This should not happen
        errorText = WPUnexpectedErrorMessage;
    }
    
    if([dictionary objectForKey: @"error"] != (id)[NSNull null] &&
       [[dictionary objectForKey: @"error"] length]) {
        errorCategory = [dictionary objectForKey: @"error"];
    }
    else {
        // This should not happen
        errorCategory = WPErrorCategoryNone;
    }
    
    [details setValue: errorText forKey: NSLocalizedDescriptionKey];
    [details setValue: errorCategory forKey: WPErrorCategoryKey];
    
    return [NSError errorWithDomain: WePayAPIDomain code: errorCode userInfo: details];
}


/*
 Handle API call response.
 Calls successHandler with returned dictionary.
 Calls errorhandler with NSError.
 */
+ (void) processResponse: (NSURLResponse *) response data: (NSData *) data error: (NSError *) error successBlock: (WPSuccessBlock) successHandler errorHandler: (WPErrorBlock) errorHandler {
    NSDictionary * dictionary = nil;
    NSString * errorCode = nil;
    
    if([data length] >= 1)
    {
        dictionary = [NSJSONSerialization JSONObjectWithData: data options: kNilOptions error: nil];
        
        if(dictionary != nil && [dictionary objectForKey: @"error_code"] != (id)[NSNull null]) {
            errorCode = [dictionary objectForKey: @"error_code"];
        }
    }
    
    if(dictionary != nil && error == nil)
    {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        
        if(statusCode == 200) {
            successHandler(dictionary);
        }
        else {
            errorHandler([self errorFromResponse: dictionary]);
        }
    }
    else if(dictionary == nil && error == nil) {
        errorHandler([self errorFromResponse: dictionary]);
    }
    else if (error != nil) {
        errorHandler(error);
    }
}


/*
 Make API calls.
 */
+ (void) makeRequestToEndPoint: (NSString *) endpoint values: (NSDictionary *) params accessToken: (NSString *) accessToken successBlock: (WPSuccessBlock) successHandler errorHandler: (WPErrorBlock) errorHandler {
    
    NSURL * callUrl = [self apiUrlWithEndpoint: endpoint];
    NSMutableURLRequest * request = [[NSMutableURLRequest alloc] initWithURL: callUrl];
    
    [request setHTTPMethod: @"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"charset" forHTTPHeaderField:@"utf-8"];
    [request setValue: [NSString stringWithFormat: @"WePay IOS SDK %@", version] forHTTPHeaderField:@"User-Agent"];
    
    // Set access token
    if(accessToken != nil) {
        [request setValue: [NSString stringWithFormat: @"Bearer: %@", accessToken] forHTTPHeaderField:@"Authorization"];
    }
    
    NSError *parseError = nil;
    
    // Get json from nsdictionary parameter
    [request setHTTPBody: [NSJSONSerialization dataWithJSONObject: params options: kNilOptions error: &parseError]];

    if(parseError) {
        errorHandler(parseError);
    }
    else
    {
        NSOperationQueue *queue = [NSOperationQueue mainQueue];
        
        [NSURLConnection sendAsynchronousRequest: request
                                           queue: queue
                               completionHandler:^(NSURLResponse *response, NSData  *data, NSError * requestError) {
                                   // Process response from server.
                                   [self processResponse:response data: data error: requestError successBlock:successHandler errorHandler: errorHandler];
                                   
        }];
    }
}

@end
