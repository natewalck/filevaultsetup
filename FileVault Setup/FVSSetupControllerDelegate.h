//
//  FVSSetupControllerDelegate.h
//  FileVault Setup
//
//  Created by Sam Marshall on 5/10/14.
//  Copyright (c) 2014 Simon Fraser Universty. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FVSSetupControllerDelegate

- (void)setupDidEndWithError:(NSAlert *)alert;
- (void)setupDidEndWithSuccess:(NSAlert *)alert;
- (void)setupDidEndWithAlreadyEnabled:(NSAlert *)alert;
- (void)setupDidEndWithNotRoot:(NSAlert *)alert;

@end
