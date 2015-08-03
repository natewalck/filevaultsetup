//
//  FVSApplicationInstance.h
//  FileVault Setup
//
//  Created by Sam Marshall on 5/10/14.
//  Copyright (c) 2014 Simon Fraser Universty. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FVSApplicationInstance : NSObject

+ (BOOL)runningAsRoot;
+ (int)setUserId:(uid_t)uid;
+ (BOOL)rootVolumeIsEncrypted;
+ (BOOL)valueForDefaultsKey:(NSString *)key;

@end
