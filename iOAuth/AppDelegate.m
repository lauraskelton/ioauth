//
//  AppDelegate.m
//  iOAuth
//
//  Created by Laura Skelton on 8/4/14.
//  Copyright (c) 2014 lauraskelton. All rights reserved.
//

#import "AppDelegate.h"
#import "OAuthHandler.h"

@interface AppDelegate () <OAuthHandlerDelegate>

-(void)getMyName:(id)sender;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // simple version, for an API that does not use state or scope
    //[[OAuthHandler sharedHandler] authenticateWithDelegate:self];
    
    // complex version for an API that uses state or scope, eg. Vimeo
    [[OAuthHandler sharedHandler] authenticateWithDelegate:self usesState:YES withScope:nil];
    
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    // lsioauth://oauth?access_token=324235253442
    
    NSLog(@"url recieved: %@", url);
    
    if ([[url host] isEqualToString:@"oauth"]) {
        // parse the authentication code query
        [[OAuthHandler sharedHandler] authorizeFromExternalURL:url delegate:self];
    }
    
    return YES;
}

#pragma mark - API Calls

-(void)getMyName:(id)sender
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.vimeo.com/me"]];
    
    // make sure to sign the request with the OAuth access token before calling the API!
    [[OAuthHandler sharedHandler] signRequest:request withCallback:^(NSMutableURLRequest *signedRequest) {
        
        [NSURLConnection sendAsynchronousRequest:signedRequest
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
                                   
               // handle the response here as usual
               
               NSError *e;
               NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&e];

               NSLog(@"response: %@, data: %@", response, jsonDict);
               
               UIAlertView *alertView = [ [UIAlertView alloc] initWithTitle:@"Logged In"
                                                                    message:[jsonDict objectForKey:@"name"]
                                                                   delegate:self
                                                          cancelButtonTitle:@"OK"
                                                          otherButtonTitles:nil];
               [alertView show];
               
           }];
        
    }];
}

#pragma mark - OAuthHandler Delegate

- (void)oauthHandlerDidAuthorize
{
    // let application know that we can access the API now
    NSLog(@"Authentication success!");
    
    [self getMyName:nil];
}

- (void)oauthHandlerDidFailWithError:(NSString *)errorMessage
{
    // Authentication failed
    UIAlertView *alertView = [ [UIAlertView alloc] initWithTitle:@"Authorization Failed"
                                                         message:errorMessage
                                                        delegate:self
                                               cancelButtonTitle:@"Dismiss"
                                               otherButtonTitles:nil];
    [alertView show];
    
}

@end
