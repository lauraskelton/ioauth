//
//  OAuthHandler.m
//  iOAuth
//
//  Created by Laura Skelton on 6/21/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

#import "OAuthHandler.h"
#import "QueryParser.h"
#import "OAuthHandler_Internal.h"
#import "Configuration.h"


@implementation OAuthHandler

@synthesize delegate, code;

- (id)init
{
    
    // designated initializer
    self = [super init];
    if (self) {
        
    }
    return self;
}

#pragma mark - Public

+ (OAuthHandler *)sharedHandler
{
    static OAuthHandler *_sharedHandler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedHandler = [[OAuthHandler alloc] init];
        
        Configuration *config = [Configuration new];
        _sharedHandler.thisClientID = config.thisClientID;
        _sharedHandler.thisClientSecret = config.thisClientSecret;
        _sharedHandler.thisRedirectURI = config.thisRedirectURI;
        _sharedHandler.thisAuthURL = config.thisAuthURL;
        _sharedHandler.thisTokenURL = config.thisTokenURL;
        _sharedHandler.tokenIsValid = NO;
        config = nil;

    });
    
    return _sharedHandler;
}

- (void)authenticateWithDelegate:(id)sender
{
    self.delegate = sender;
    [self handleUserSignIn:nil];
}

- (void)authorizeFromExternalURL:(NSURL *)url delegate:(id)sender
{
    self.delegate = sender;
    [self handleAuthTokenURL:url];
}

- (void)signRequest:(NSMutableURLRequest *)request withCallback:(OAuthHandlerSignedRequestCallback)callback
{
    if (self.tokenIsValid) {
        if (callback)
        {
            callback([self signedRequest:request]);
        }
    } else {
        [self refreshAccessTokenWithRequestCallback:^() {
            if (callback)
            {
                callback([self signedRequest:request]);

            }
        }];
    }

}

#pragma mark - Internal

-(BOOL)hasAccessTokenKey:(id)sender
{
    if (![[NSUserDefaults standardUserDefaults] objectForKey:kiOAuthAccessTokenKey]) {
        return false;
    }
    return true;
}

-(NSMutableURLRequest *)signedRequest:(NSMutableURLRequest *)request
{
    [request setValue:[NSString stringWithFormat:@"Bearer %@", [[NSUserDefaults standardUserDefaults] objectForKey:kiOAuthAccessTokenKey]] forHTTPHeaderField:@"Authorization"];
    return request;
}

#pragma mark - API

-(void)handleUserSignIn:(id)sender
{
    // first, try to refresh token. if fails, then launch external sign-in.
    
    if (self.code == nil && [[NSUserDefaults standardUserDefaults] objectForKey:kiOAuthRefreshTokenKey] == nil) {
        [self launchExternalSignIn:nil];
    } else {
        [self requestAccessToken];
    }
}

-(void)launchExternalSignIn:(id)sender
{
    
    NSURL *authURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?response_type=code&client_id=%@&redirect_uri=%@", self.thisAuthURL, self.thisClientID, self.thisRedirectURI]];
    
    [[UIApplication sharedApplication] openURL:authURL];
}

-(NSURLRequest *)accessTokenRequest
{
    NSURL *tokenURL = [NSURL URLWithString:self.thisTokenURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:tokenURL];
    
    [request setHTTPMethod:@"POST"];
    NSString *postString;
    if (self.code != nil) {
        postString = [NSString stringWithFormat:@"grant_type=authorization_code&client_id=%@&client_secret=%@&redirect_uri=%@&code=%@", self.thisClientID, self.thisClientSecret, self.thisRedirectURI, self.code];
        self.code = nil;
    } else {
        NSLog(@"refreshing token");
        postString = [NSString stringWithFormat:@"grant_type=refresh_token&client_id=%@&client_secret=%@&refresh_token=%@", self.thisClientID, self.thisClientSecret, [[NSUserDefaults standardUserDefaults] objectForKey:kiOAuthRefreshTokenKey]];
    }
    [request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];
    NSLog(@"request: %@ method: %@ httpBody: %@", request, request.HTTPMethod, [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding]);
    return request;
}

-(BOOL)handleResponseWithData:(NSData *)data andError:(NSError *)error
{
    if (error == nil && data != nil) {
        NSString *responseBody = [ [NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        if (responseBody != nil) {

            NSLog(@"response: %@", responseBody);
            
            //NSData *jsonData = [responseBody dataUsingEncoding:NSUTF8StringEncoding];
            
            NSError *e;
            NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&e];
            
            NSLog(@"jsonDict: %@", jsonDict);
            
            if (e != nil) {
                NSLog(@"error creating json object from response: %@", e);
                if (self.code == nil) {
                    [self launchExternalSignIn:nil];
                }
                return false;
            } else if ([jsonDict objectForKey:@"error"] != nil){
                NSLog(@"error requesting access token: %@", [jsonDict objectForKey:@"error"]);
                if (self.code == nil) {
                    [self launchExternalSignIn:nil];
                }
                return false;
            } else {
                if ([jsonDict objectForKey:@"access_token"] != nil && [jsonDict objectForKey:@"refresh_token"] != nil) {
                    if ([[jsonDict objectForKey:@"access_token"] length] > 0 && [[jsonDict objectForKey:@"refresh_token"] length] > 0) {
                        [[NSUserDefaults standardUserDefaults] setObject:[jsonDict objectForKey:@"access_token"] forKey:kiOAuthAccessTokenKey];
                        [[NSUserDefaults standardUserDefaults] setObject:[jsonDict objectForKey:@"refresh_token"] forKey:kiOAuthRefreshTokenKey];
                        self.tokenIsValid = YES;
                        if ([jsonDict objectForKey:@"expires_in"]) {
                            if ([[jsonDict objectForKey:@"expires_in"] doubleValue]) {
                                [self performSelector:@selector(tokenShouldRefresh:) withObject:nil afterDelay:([[jsonDict objectForKey:@"expires_in"] doubleValue] - 200)];
                            }
                        }
                        
                        return true;
                    }
                }
            }
        }
    } else {
        NSLog(@"Error generating OAuth access token: %@", error);
    }
    return false;
}

-(void)tokenShouldRefresh:(id)sender
{
    self.tokenIsValid = NO;
}

-(void)refreshAccessTokenWithRequestCallback:(OAuthHandlerRefreshTokenCallback)callback
{
    NSURLRequest *request = [self accessTokenRequest];

    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               
                               if ([self handleResponseWithData:data andError:error]) {
                                   if (callback)
                                   {
                                       callback();
                                   }
                               } else {
                                   // Should we do a popup to tell the user that login failed?
                                   NSLog(@"Error handling login response.");
                               }
                               
                           }];
}

-(void)requestAccessToken
{
    
    NSURLRequest *request = [self accessTokenRequest];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                               
                               if ([self handleResponseWithData:data andError:error]) {
                                   [self.delegate oauthHandlerDidAuthorize];
                               } else {
                                   // Should we do a popup to tell the user that login failed?
                                   NSLog(@"Error handling login response.");
                               }
                               
                           }];
}

-(void)handleAuthTokenURL:(NSURL *)url
{
    // handle query here
    NSDictionary *dict = [QueryParser parseQueryString:[url query]];
    
    if ([dict objectForKey:@"error"] != nil) {
        [self.delegate oauthHandlerDidFailWithError:[dict objectForKey:@"error"]];
    } else if ([dict objectForKey:@"code"] != nil) {
        // Use the Authorization Code to request an Access Token from the API
        self.code = [dict objectForKey:@"code"];
        [self requestAccessToken];
    } else {
        [self.delegate oauthHandlerDidFailWithError:@"Authorization code not found. Failed to log in to API."];
    }
    
}

@end
