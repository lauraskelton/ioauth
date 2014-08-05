//
//  OAuthHandler_Private.h
//  iOAuth
//
//  Created by Laura Skelton on 7/2/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

#define kiOAuthAccessTokenKey @"LESiOAuthAccessTokenStorageKey42"
#define kiOAuthRefreshTokenKey @"LESiOAuthRefreshTokenStorageKey42"
#define kiOAuthStateKey @"LESiOAuthStateStorageKey42"
#define kiOAuthDoesntExpireKey @"LESiOAuthDoesntExpireStorageKey42"

typedef void(^OAuthHandlerRefreshTokenCallback)();

@interface OAuthHandler ()

@property (nonatomic, retain) NSString *code;
@property (nonatomic, retain) NSString *thisClientID;
@property (nonatomic, retain) NSString *thisClientSecret;
@property (nonatomic, retain) NSString *thisRedirectURI;
@property (nonatomic, retain) NSString *thisAuthURL;
@property (nonatomic, retain) NSString *thisTokenURL;
@property (nonatomic, retain) NSString *scope;
@property (nonatomic, assign) BOOL tokenIsValid;

-(void)launchExternalSignIn:(id)sender;
-(void)requestAccessToken;
-(NSURLRequest *)accessTokenRequest;
-(BOOL)handleResponseWithData:(NSData *)data andError:(NSError *)error;
-(BOOL)hasAccessTokenKey:(id)sender;
-(void)handleUserSignIn:(id)sender;
-(void)handleAuthTokenURL:(NSURL *)url;
- (NSMutableURLRequest *)signedRequest:(NSMutableURLRequest *)request;
-(NSString *)randomStateString;

@end
