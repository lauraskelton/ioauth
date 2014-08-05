//
//  Configuration.m
//  iOAuth
//
//  Created by Laura Skelton on 7/10/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

#import "Configuration.h"

static NSString * const APIDictKey = @"APICredentials";

@interface Configuration ()
@property (nonatomic, strong) NSDictionary *plist;
@end

@implementation Configuration

- (id)init {
    return [self initWithBundle:NSBundle.mainBundle];
}

- (id)initWithBundle:(NSBundle *)bundle {
    self = [super init];
    if (!self) return nil;
    
    NSString *plistPath = [bundle pathForResource:@"Configuration" ofType:@"plist"];
    if (plistPath == nil) {
        [NSException raise:@"FileNotFoundException" format:@"No Configuration.plist file was found."];
    }
    self.plist = [[NSDictionary alloc] initWithContentsOfFile:plistPath];
    
    return self;
}

- (NSString *)thisClientID {
    return self.plist[APIDictKey][@"ClientID"];
}

- (NSString *)thisClientSecret {
    return self.plist[APIDictKey][@"ClientSecret"];
}

- (NSString *)thisRedirectURI {
    return self.plist[APIDictKey][@"RedirectURI"];
}

- (NSString *)thisAuthURL {
    return self.plist[APIDictKey][@"AuthURL"];
}

- (NSString *)thisTokenURL {
    return self.plist[APIDictKey][@"TokenURL"];
}

@end
