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

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[OAuthHandler sharedHandler] applicationLaunchSignInCheckWithDelegate:self];
    
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

#pragma mark - OAuthHandler Delegate

- (void)oauthHandlerDidAuthorize
{
    // let application know that we can access the API now
    UIAlertView *alertView = [ [UIAlertView alloc] initWithTitle:@"Authorization Succeeded"
                                                         message:@"Successfully authorized API"
                                                        delegate:self
                                               cancelButtonTitle:@"Dismiss"
                                               otherButtonTitles:nil];
    [alertView show];
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
