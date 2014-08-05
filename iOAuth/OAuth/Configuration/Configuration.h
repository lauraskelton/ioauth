//
//  Configuration.h
//  iOAuth
//
//  Created by Laura Skelton on 7/10/14.
//  Copyright (c) 2014 Laura Skelton. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Configuration : NSObject

@property (nonatomic, readonly) NSString *thisClientID;
@property (nonatomic, readonly) NSString *thisClientSecret;
@property (nonatomic, readonly) NSString *thisRedirectURI;
@property (nonatomic, readonly) NSString *thisAuthURL;
@property (nonatomic, readonly) NSString *thisTokenURL;

@end