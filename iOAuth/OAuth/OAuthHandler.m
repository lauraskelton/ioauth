//
//  OAuthHandler.m
//  iOAuth
//
//  Created by Laura Skelton on 6/21/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

// verbose logging macro
#define NSLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

#import "OAuthHandler.h"
#import "QueryParser.h"
#import "OAuthHandler_Internal.h"
#import "Configuration.h"
#import "NSString+Base64.h"


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
        if ([[NSUserDefaults standardUserDefaults] objectForKey:kiOAuthDoesntExpireKey] && [[[NSUserDefaults standardUserDefaults] objectForKey:kiOAuthDoesntExpireKey] boolValue]) {
            _sharedHandler.tokenIsValid = YES;
        } else {
            _sharedHandler.tokenIsValid = NO;
        }
        config = nil;

    });
    
    return _sharedHandler;
}

- (void)authenticateWithDelegate:(id)sender
{
    [self authenticateWithDelegate:sender usesState:NO withScope:nil];
}

- (void)authenticateWithDelegate:(id)sender usesState:(BOOL)usesState withScope:(NSString *)scope
{
    self.delegate = sender;
    
    if (self.tokenIsValid) {
        [delegate oauthHandlerDidAuthorize];
    } else {
        self.scope = scope;
        
        if (usesState) {
            [[NSUserDefaults standardUserDefaults] setObject:[self randomStateString] forKey:kiOAuthStateKey];
        }
        
        [self handleUserSignIn:nil];
    }
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

-(NSString *)randomStateString
{
    // generate random number, cast to a string
    return [NSString stringWithFormat:@"%d", arc4random_uniform(189088837)];
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
    NSMutableString *urlString = [[NSString stringWithFormat:@"%@?response_type=code&client_id=%@&redirect_uri=%@", self.thisAuthURL, self.thisClientID, self.thisRedirectURI] mutableCopy];
    
    // add scope if required
    if (self.scope) {
        [urlString appendString:[NSString stringWithFormat:@"&scope=%@", self.scope]];
    }
    
    // add state value if required
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kiOAuthStateKey]) {
        [urlString appendString:[NSString stringWithFormat:@"&state=%@", [[NSUserDefaults standardUserDefaults] objectForKey:kiOAuthStateKey]]];
    }
    
    NSURL *authURL = [NSURL URLWithString:urlString];
    
    [[UIApplication sharedApplication] openURL:authURL];
}

-(NSURLRequest *)accessTokenRequest
{
    NSURL *tokenURL = [NSURL URLWithString:self.thisTokenURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:tokenURL];
    
    NSString *clientHeaderString = [NSString stringWithFormat:@"%@:%@", self.thisClientID, self.thisClientSecret];
    NSString *encodedString = [NSString base64String:clientHeaderString];
    [request setValue:[NSString stringWithFormat:@"basic %@", encodedString] forHTTPHeaderField:@"Authorization"];
    
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
                if ([jsonDict objectForKey:@"access_token"] && [[jsonDict objectForKey:@"access_token"] length] > 0) {
                    [[NSUserDefaults standardUserDefaults] setObject:[jsonDict objectForKey:@"access_token"] forKey:kiOAuthAccessTokenKey];
                    if ([jsonDict objectForKey:@"refresh_token"] && [[jsonDict objectForKey:@"refresh_token"] length] > 0) {
                        [[NSUserDefaults standardUserDefaults] setObject:[jsonDict objectForKey:@"refresh_token"] forKey:kiOAuthRefreshTokenKey];
                         }
                    self.tokenIsValid = YES;
                    if ([jsonDict objectForKey:@"expires_in"] && [[jsonDict objectForKey:@"expires_in"] doubleValue]) {
                        [self performSelector:@selector(tokenShouldRefresh:) withObject:nil afterDelay:([[jsonDict objectForKey:@"expires_in"] doubleValue] - 200)];
                        [[NSUserDefaults standardUserDefaults] setObject:@(NO) forKey:kiOAuthDoesntExpireKey];
                    } else {
                        [[NSUserDefaults standardUserDefaults] setObject:@(YES) forKey:kiOAuthDoesntExpireKey];
                    }
                    
                    return true;
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
        // check if state matches
        if ([[NSUserDefaults standardUserDefaults] objectForKey:kiOAuthStateKey]) {
            if (![dict objectForKey:@"state"] || ![[dict objectForKey:@"state"] isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:kiOAuthStateKey]]) {
                NSLog(@"Error: state returned does not match state sent. Possible security issue.");
                return;
            }
        }
        
        // Use the Authorization Code to request an Access Token from the API
        self.code = [dict objectForKey:@"code"];
        [self requestAccessToken];
    } else {
        [self.delegate oauthHandlerDidFailWithError:@"Authorization code not found. Failed to log in to API."];
    }
    
}

@end
